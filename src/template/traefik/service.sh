#!/bin/bash
######################################################################################
###############################  FUNCTION  ###########################################
######################################################################################
function service_edit {

  if [[ "$1" == "service.env" ]]; then
    #Check if password was set and ask to generate them
    ask_password_helper "human" CFG_ADMIN_PWD "${SERVICE_ENV}"

    #Define hash variable for substitution
    export CFG_ADMIN_PWD_HASH
    CFG_ADMIN_PWD_HASH=$(htpasswd -nbBC 10 admin "${CFG_ADMIN_PWD}")
    old_password=$(load_env_value CFG_ADMIN_PWD "${SERVICE_CACHE}/configs.bak/service.env") || :
    if [[ "${old_password}" != "${CFG_ADMIN_PWD}" ]]; then
      echo "New admin password to setup for '${SERVICE}'"
      file_subst_vars "${SERVICE_TOML}" CFG_ADMIN_PWD_HASH
      if ! grep "${CFG_ADMIN_PWD_HASH}" "${SERVICE_TOML}"; then
        traefik_change_password "admin" "${CFG_ADMIN_PWD_HASH}" "${SERVICE_TOML}"
      fi
    fi

    #Change Host if needed
    old_host=$(load_env_value CFG_HOST "${SERVICE_CACHE}/configs.bak/service.env") || :
    if [[ "${old_host}" != "${CFG_HOST}" ]]; then
      echo "New host for '${SERVICE}' proxy"
      traefik_change_host "${CFG_HOST}" "${SERVICE_TOML}"
    fi

    ask_email_helper CFG_EMAIL_TLS "${SERVICE_ENV}"
    ask_ip_cidr_helper CFG_WHITELIST "${SERVICE_ENV}"
  fi

}

function host_setup {

  if [[ "${COMMAND}" == "install" ]]; then
    mkdir -vp "${HOME}"/containers/traefik/
    mkdir -vp "${HOME}"/containers/traefik/{configs.d,acme,tls}

    echo "Generate default TLS"
    folder="${HOME}"/containers/traefik/tls

    #Ex: -subj "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=yourdomain.com" // /E={email} ?
    openssl req -x509 -sha256 -newkey rsa:4096 -keyout "${folder}"/default.key -out "${folder}"/default.crt \
      -days 3650 -nodes -subj "/emailAddress=${CFG_EMAIL_TLS}/CN=${CFG_DOMAIN}"
    #TODO : Or Ask path to get key data
  fi

  #Take Traefik files of others services
  rm -vf "${CFG_PATH_TRAEFIK:?}"/*.toml

  for item in "${SERVICES_INSTALLED[@]}"; do
    [[ -n "${item}" ]] || continue # handle empty list
    #Get home directory of the service
    home_item=$(getent passwd "${item}" | cut -d: -f6)
    #Copy service proxy if they got the file
    if [[ -f "${home_item}"/configs/service.toml ]]; then
      cp -vf "${home_item}"/configs/service.toml "${CFG_PATH_TRAEFIK:?}"/"${item}".toml
    fi
  done

  #Update Core config
  cp -vf "${HOME}"/configs/traefik.toml "${HOME}"/containers/traefik/traefik.toml
  #Change permission to be read by container
  chown -R "${SERVICE}":"${SERVICE}" "${CFG_PATH_TRAEFIK:?}"

}

function service_set {

  podman create --network=host --name "${CFG_NAME}" \
    --label "io.containers.autoupdate=registry" \
    -v "${HOME}"/containers/traefik/traefik.toml:/etc/traefik/traefik.toml:ro \
    -v "${CFG_PATH_TRAEFIK}":/etc/traefik/configs.d:ro \
    -v "${HOME}"/containers/traefik/tls:/etc/traefik/tls:ro \
    -v "${HOME}"/containers/traefik/acme:/etc/traefik/acme \
    "${CFG_IMAGE}"

}
