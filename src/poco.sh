#!/usr/bin/env bash
# Copyright (C) 2022 carbon severac (carbon.severac@tuta.io)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

######################################################################################
#################################  INFOS  ############################################
######################################################################################
# square brackets [optional option]
# angle brackets <required argument>
# curly braces {default values}
# parenthesis (miscellaneous info)
#${0%/*}: Command name // ${0##*/} : Parent Path

function poco_help() {
  printf "Rootless containers service configuration helper and manager\n\n"
  printf "Usage:\n"
  printf "\t%s\n" "$(basename "${0%/*}") [options] command service"
  ##
  printf "\nAvailable Commands:\n"
  printf "\t%s\t%s\n" "setup    " "Setup Poco configuration and do optional installation on the host if needed"
  printf "\t%s\t%s\n" "install  " "Install a service from a template, an archive or a path"
  printf "\t%s\t%s\n" "restore  " "Install a service from a provided archive or path"
  printf "\t%s\t%s\n" "update   " "Update a service (will disable service before update)"
  printf "\t%s\t%s\n" "uninstall" "Uninstall a service"
  printf "\t%s\t%s\n" "enable   " "Enable a service"
  printf "\t%s\t%s\n" "disable  " "Disable a service"
  printf "\t%s\t%s\n" "restart  " "Restart a service"
  printf "\t%s\t%s\n" "edit     " "Edit service configuration files "
  printf "\t%s\t%s\n" "backup   " "Generate an service archive"
  printf "\t%s\t%s\n" "login    " "Allow user to login to service or in container service"
  printf "\t%s\t%s\n" "logs     " "Display systemd logs from the services one by one or the specified one"
  printf "\t%s\t%s\n" "status   " "Display information about the service (poco, podman and systemd)"
  printf "\t%s\t%s\n" "ps       " "Show information about all services installed or the services set by user"
  printf "\t%s\t%s\n" "help     " "Show poco help or service help is exist  "
  printf "\t%s\t%s\n" "version  " "Show poco version or service containers version   "
  printf "\t%s\t%s\n" "template " "Show all template available with poco "
  printf "\t%s\t%s\n" "event    " "Used by poco service to trig event like 'boot'. User don't need to use it"
  ##
  printf "\nOptions:\n"
  printf "\t%s\t%s\n" "--expert,  -e" "Allow expert mode. That mean you will see more information on status or get the possibility to edit advanced files."
  printf "\t%s\t%s\n" "--force,   -f" "Force option allow to discard question asked and confirm every question."
  printf "\t%s\t%s\n" "--type,    -t" "This option is used when user install or restore a service and want use a template by naming it. It specify the event name when event command is called too."
  printf "\t%s\t%s\n" "--path,    -p" "User provided archive or directory path used when install or restore a service."
  printf "\t%s\t%s\n" "--output,  -o" "Directory path to store backup when uninstall or backup command is used."
  printf "\t%s\t%s\n" "--verbose, -v" "(WIP) Display line and command error if happen."
  printf "\t%s\t%s\n" "--no-backup  " "Allow uninstall a service without create a backup."
  printf "\t%s\t%s\n" "--size       " "Display size parameter when using 'poco ps' or 'poco status'"
}

function poco_version() {
  printf "%s\n" "Poco version ${GIT_VERSION_SHORT}"
  exit 0
}

######################################################################################
#################################  INIT  #############################################
######################################################################################
#Current Path
CPTH="$(pwd -P)"
#Script Path
SPTH="$(
  cd "$(dirname "$(readlink -f "$0")")" >/dev/null 2>&1
  pwd -P
)"
#Script File
SCRIPT="$(realpath -s "$(readlink -f "$0")")"
#Script Args
SARGS=("$@")

#exit when any command fails
set -eE # same as: `set -o errexit -o errtrace`

#Default Callback function set when error occur
trap 'onError ${LINENO}' ERR

######################################################################################
#Script need be executed as root
if [[ "${EUID}" -ne 0 ]]; then
  if which sudo &>/dev/null; then
    #Ask privilege if user is not a service.
    sudo "${SCRIPT}" "${SARGS[@]}" || true # ignore failure
    exit 0
  else
    printf "%s\n" "'poco' must be run as root."
    exit 1
  fi
fi

#Warning: mandatory 'cd'.  Use "CPTH" to get relative path from arguments
#Bug: Loginctl will not work if launched from a directory with not enough permission like 700.
cd "${SPTH:?}"

#Load function library
set -a
# shellcheck source=./src/lib/bash_utils.sh
source "${SPTH}"/lib/bash_utils.sh
# shellcheck source=./src/lib/poco_parser.sh
source "${SPTH}"/lib/poco_parser.sh
# shellcheck source=./src/lib/libpoco.sh
source "${SPTH}"/lib/libpoco.sh
# shellcheck source=./src/lib/service_utils.sh
source "${SPTH}"/lib/service_utils.sh
set +a

#Load poco additional command
# shellcheck source=./src/lib/poco_template.sh
source "${SPTH}"/lib/poco_template.sh

#Load main configurations
readonly PODMAN_VERSION="3.4.4"
readonly POCO_CONFIGS="/etc/poco.conf"
if [[ ! -f "${POCO_CONFIGS}" ]]; then
  log_error "Poco configuration file don't exist: ${POCO_CONFIGS}"
  log_error "Reinstall if needed"
  exit 1
else
  load_env_file "${POCO_CONFIGS}"
fi

######################################################################################
#################################  GENERAL  ##########################################
######################################################################################
#Function called after "edition" when install/restore
function _cmd_install_pre() {

  #Create User
  add_service_user "${SERVICE}" "${ARG_OUTPUT}"
  echo "Add ${SERVICE} to group ${CFG_GROUP}"
  usermod -a -G "${CFG_GROUP}" "${SERVICE}"
  #Update default variables and paths
  change_system_variable "${SERVICE}"
  #Set home permission
  chmod 700 "${HOME}"

  #Update SERVICES_INSTALLED with new service installed
  IFS=" " read -r -a SERVICES_INSTALLED <<<"$(getent group "${CFG_GROUP}" | cut -d: -f4 | tr "," " ")"

  #Add Default Podman configs
  mkdir -p "${HOME}"/.config/containers/
  install -g "${SERVICE}" -o "${SERVICE}" -m 600 "${SPTH}"/containers.conf "${HOME}"/.config/containers/
  install -g "${SERVICE}" -o "${SERVICE}" -m 600 "${SPTH}"/registries.conf "${HOME}"/.config/containers/
  install -g "${SERVICE}" -o "${SERVICE}" -m 600 "${SPTH}"/storage.conf "${HOME}"/.config/containers/
}

#Function called after "edition" when install/restore
function _cmd_install_post() {

  #service specific install/restore
  host_setup

  #Permission Set
  chown -R "${SERVICE}":"${SERVICE}" "${HOME}"/
  #
  chown -R root:"${SERVICE}" "${SERVICE_FOLDER:?}"
  chmod 750 "${SERVICE_FOLDER:?}"
  chmod 640 "${SERVICE_FOLDER:?}"/*
  chown root:root "${SERVICE_FOLDER:?}"/*.toml "${SERVICE_SCRIPT:?}"
  chmod 600 "${SERVICE_ENV:?}" "${SERVICE_FOLDER:?}"/*.toml "${SERVICE_SCRIPT:?}"
}

function _is_service_installed() {
  local home_user
  home_user=$(getent passwd "${1}" | cut -d: -f6)
  if [[ -f "${home_user}"/.config/poco/install ]]; then
    return 1
  fi
  return 0
}

function _is_service_enable() {

  if loginctl show-user "${1}" --property=Linger 2>/dev/null | grep -q 'yes'; then
    return 0
  fi
  return 1
}
export -f _is_service_enable

function _is_service_started() {

  local item
  local home_user
  #Get home directory of the service
  home_user=$(getent passwd "${1}" | cut -d: -f6)

  #Check Systemd Service
  for item in "${home_user}"/.config/systemd/user/*.service; do
    [[ -f "${item}" ]] || continue # handle empty list
    if ! systemctl is-active --user --quiet "$(basename "${item}")"; then
      return 1
    fi
  done

  #Check if containers are running
  local containers_nb
  containers_nb="$(podman ps | wc -l)"
  if [[ ${containers_nb} -le 1 ]]; then
    return 1
  fi
  return 0
}
export -f _is_service_started

######################################################################################
###########################  INSTALL // RESTORE   ####################################
######################################################################################
function _install_mode {
  #$1: mode
  touch "${HOME}"/.config/poco/install
  echo "${1:-"none"}" >"${HOME}"/.config/poco/install
}

function _control_folder_install() {
  if [[ ! -f "${INSTALL_PATH:?}"/service.env ]]; then
    log_error "Missing file: ${INSTALL_PATH}/service.env"
    return 1
  fi
  if [[ ! -f "${INSTALL_PATH:?}"/service.sh ]]; then
    log_error "Missing file: ${INSTALL_PATH}/service.sh"
    return 1
  fi
}

function _control_folder_restore() {

  if [[ ! -f "${INSTALL_PATH:?}"/configs/service.env ]]; then
    log_error "Missing file: ${INSTALL_PATH}/configs/service.env"
    return 1
  fi
  if [[ ! -f "${INSTALL_PATH:?}"/configs/service.sh ]]; then
    log_error "Missing file: ${INSTALL_PATH}/configs/service.sh"
    return 1
  fi
  if [[ ! -d "${INSTALL_PATH:?}"/containers ]]; then
    log_error "Missing folder: ${INSTALL_PATH}/containers"
    return 1
  fi

  if [[ "$(basename "${INSTALL_PATH}")" != "${SERVICE}" ]]; then
    log_warn "You restore a service with a different name"
  fi

  #Remove files if exist that was not needed
  rm -f "${INSTALL_PATH}"/.profile
  rm -f "${INSTALL_PATH}"/.bash*
  rm -rf "${INSTALL_PATH}"/.local
  rm -rf "${INSTALL_PATH}"/.config/systemd
  rm -rf "${INSTALL_PATH}"/.config/cni

  #Check if service is already in home folder
  if [[ "$(dirname "${INSTALL_PATH:?}")" == "${ARG_OUTPUT:-"/home"}" ]]; then
    log_warn "We restore a service in '${SERVICE}' home directory"
    mv "${INSTALL_PATH:?}" "${TMP_PATH}"
    INSTALL_PATH="${TMP_PATH}"/"$(basename "${INSTALL_PATH:?}")"
  fi
}

#Function called before "edition"
function poco_cmd_install() {

  #$1: Step
  case "${1}" in
  ######################################################################################
  #Command with optional SERVICE
  1)
    local home_user
    home_user=$(getent passwd "${SERVICE}" | cut -d: -f6)
    if [[ -f "${home_user}"/.config/poco/install ]]; then
      local mode
      mode=$(cat "${home_user}"/.config/poco/install)
      #Check if restore or install was used for this service
      if [[ "${mode}" != "${COMMAND}" ]]; then
        log_error "'${SERVICE}' was executed with '${mode}' command"
        return 1
      fi
      #Jump if Creation step was already done
      change_system_variable "${SERVICE}"
      return 0
    fi
    #Start first step
    style_echo "1) Install system user and copy configuration" "green" "underline"
    #At this point "INSTALL_PATH" is set. check if directory content is a "install" service folder
    if [[ "${COMMAND}" == "install" ]]; then
      _control_folder_install
    else
      _control_folder_restore
    fi
    local home_dir_list
    # shellcheck disable=SC2034
    mapfile -t home_dir_list < <(getent passwd | cut -d: -f6)
    if array_contains home_dir_list "${INSTALL_PATH}"; then
      log_error "Can't '${COMMAND}' from an existing service"
      return 1
    fi
    ###############################################################
    _cmd_install_pre
    #Create main services folders
    mkdir -vp "${HOME}"/.config/poco
    mkdir -vp "${HOME}"/configs
    mkdir -vp "${HOME}"/containers/
    #Copy all files needed by services
    ###############################################################
    if [[ "${COMMAND}" == "install" ]]; then
      cp -Trf "${INSTALL_PATH:?}" "${SERVICE_FOLDER:?}"
    else
      cp -Trf "${INSTALL_PATH:?}" "${HOME}"
    fi
    #Install progress file
    _install_mode "${COMMAND}"
    ;;
  2)
    style_echo "2) User service edition" "green" "underline"
    poco_cmd_edit "substitute"
    ;;
  3)
    style_echo "3) Service installation" "green" "underline"
    _cmd_install_post
    ;;
  4)
    style_echo "4) Service first update" "green" "underline"
    exec_fn_as_service poco_cmd_update_user
    ;;

  5)
    style_echo "5) Service activation" "green" "underline"
    if ! exec_fn_as_service _user_service_enable; then
      exec_fn_as_service journalctl --user -xe #show sysd log when error
      log_error "Error when enable user systemd service"
      return 1
    fi
    ;;
  6)
    #Allow post installation containers (e.g: podman exec)
    style_echo "6) Execute custom service command" "green" "underline"
    exec_fn_as_service service_exec
    ;;
  *)
    rm "${HOME}"/.config/poco/install
    style_echo "Service '${SERVICE}' is up, '${COMMAND}' success." "green" "underline"
    return 0
    ;;
  esac
}

######################################################################################
#################################  UPDATE  ###########################################
######################################################################################
function poco_cmd_update() {

  #Update permission
  chown -R root:"${SERVICE}" "${SERVICE_FOLDER:?}"
  chmod 750 "${SERVICE_FOLDER:?}"
  chmod 640 "${SERVICE_FOLDER:?}"/*
  #
  chown root:root "${SERVICE_FOLDER:?}"/*.toml "${SERVICE_SCRIPT:?}"
  chmod 600 "${SERVICE_ENV:?}" "${SERVICE_FOLDER:?}"/*.toml "${SERVICE_SCRIPT:?}"

  #Disable
  exec_fn_as_service _user_service_disable

  #Clean container cache (if overlays changed for example)
  if [[ -n "${ARG_EXPERT}" ]]; then
    podman system reset -f
  fi

  #update from service
  host_setup
  #User update
  exec_fn_as_service poco_cmd_update_user

  #Enable
  if ! exec_fn_as_service _user_service_enable; then
    #error happen when enable, disable all
    log_error "${SERVICE} enable with error"
    return 1
  fi
  #Allow post installation containers (e.g: podman exec)
  exec_fn_as_service service_exec
}

#Called when install/restore/update
function poco_cmd_update_user() {

  #Download image
  local image_list
  local item
  #Get USER image list from environnement, we can't read file because of file permission
  mapfile -t image_list < <(printenv | grep -E "^CFG_IMAGE(.*)=" | cut -d "=" -f2-)
  #mapfile -t image_list < <(printenv | grep -E "^CFG_IMAGE(.*)=" | cut -d "=" -f2- | echo "${CFG_REGISTRY}"/"$(</dev/stdin)")
  echo "Image download list: ${image_list[*]}"
  for item in "${image_list[@]}"; do
    [[ -n "${item}" ]] || continue # handle empty list
    until podman image pull "${item}"; do
      style_echo "Fail during image pull, retry..." "yellow"
      sleep 3
    done
  done

  if ! service_set; then
    style_echo "Fail during 'service_set'" "yellow"
    podman pod rm --all
    podman container rm --all
    return 1
  fi

  if [[ ! -d "${HOME}"/.config/systemd/user ]]; then
    mkdir -p "${HOME}"/.config/systemd/user
  fi

  podman generate systemd --separator='' --container-prefix='' --pod-prefix='pod-' \
    --restart-policy="${CFG_RESTART}" --time 120 --files --new --name "${CFG_NAME}"

  #Move service after update
  mv -vf "${HOME}"/*.service "${HOME}"/.config/systemd/user

  #Reload systemd if service file(s) was edited
  systemctl --user daemon-reload

  #Remove unused image
  podman image prune --all -f
}
export -f poco_cmd_update_user # export to call as user

######################################################################################
##################################  EDIT  ############################################
######################################################################################
function poco_cmd_edit() {

  local item
  local sub

  #$1 : substitute
  if [[ "substitute" == "$1" ]]; then
    echo "Edit with substitute"
    sub=true
    generate_ramdom_port_nb "${CFG_PORT_RANGE}"
  fi

  ############################################
  #Ask if restore first.
  ############################################
  if [[ "${COMMAND}" == "edit" ]]; then
    set_style "yellow"
    if [[ -n "${ARG_BACKUP}" ]] && [[ -d "${SERVICE_CACHE}"/configs.bak ]] && yes_or_no_default "n" "Do you want restore before edit ?"; then
      rm -rf "${SERVICE_FOLDER:?}"/*
      cp -pr "${SERVICE_CACHE}"/configs.bak/* "${SERVICE_FOLDER}"
      echo "Configurations Restored"
    else
      mkdir -vp "${SERVICE_CACHE}"
      chown root:root "${SERVICE_CACHE}"
      chmod 700 "${SERVICE_CACHE}"
      rm -rf "${SERVICE_CACHE}"/configs.bak
      cp -Tpr "${SERVICE_FOLDER}" "${SERVICE_CACHE}"/configs.bak
    fi
    set_style
  fi

  ############################################
  #Update Service file is user specified it
  ############################################
  if [[ -n "${INSTALL_PATH}" ]] && [[ "${COMMAND}" == "edit" ]]; then
    service_name=$(load_env_value CFG_NAME "${INSTALL_PATH}/service.env")
    if [[ "${service_name}" != "${CFG_NAME}" ]]; then
      log_error "You attempt to update '${CFG_NAME}' with '${service_name}' service files"
      return 1
    fi
    set_style "yellow"
    if yes_or_no "Do you want update service script (.sh) ?"; then
      cp -v "${INSTALL_PATH}"/service.sh "${SERVICE_FOLDER}"
    fi
    if yes_or_no "Do you want update *.toml file(s) ?"; then
      cp -v "${INSTALL_PATH}"/*.toml "${SERVICE_FOLDER}"
    fi
    # if yes_or_no_default "N" "Do you want update '${SERVICE_ENV:?}' file ?" ; then
    #     cp -v "${INSTALL_PATH}"/service.env "${SERVICE_FOLDER}"
    #     files_subst_env "${HOME}"/configs/*.toml
    # fi

    #Substitution need to be enable if files updated
    sub=true
    set_style
  fi

  ############################################
  #Script Edition
  ############################################
  if [[ -n "${ARG_EXPERT}" ]]; then
    ${CFG_EDITOR:?} "${SERVICE_SCRIPT}"
  fi
  if ! load_env_file "${SERVICE_SCRIPT}"; then
    log_error "Can't load ${SERVICE_SCRIPT}"
    return 1
  fi

  ############################################
  #Service main env
  ############################################
  #Substitute variable if needed
  [[ -n "${sub}" ]] && files_subst_env "${SERVICE_ENV}"
  #Load variables
  load_env_file_raw "${SERVICE_ENV}"
  #Edit configuration file
  ${CFG_EDITOR:?} "${SERVICE_ENV}"
  #Reload
  load_env_file_raw "${SERVICE_ENV}"
  #Execute service edit function
  service_edit "$(basename "${SERVICE_ENV}")"
  #Reload
  load_env_file_raw "${SERVICE_ENV}"

  ############################################
  #User specific env
  ############################################
  for item in "${HOME}"/configs/*.env; do
    [[ -f "${item}" ]] || continue                  # handle empty list
    [[ "${SERVICE_ENV}" == "${item}" ]] && continue # handle service file already verified
    #Substitute variable if needed
    [[ -n "${sub}" ]] && files_subst_env "${item}"
    #Load variable
    load_env_file_raw "${item}"
    #Edit configuration file
    ${CFG_EDITOR:?} "${item}"
    #Reload
    load_env_file_raw "${item}"
    #Execute service edit function
    service_edit "$(basename "${item}")"
    #Reload
    load_env_file_raw "${item}"
  done

  ############################################
  #User specific toml file
  ############################################
  #Toml file
  files_subst_env "${HOME}"/configs/*.toml

  #Edit if expert
  if [[ -n "${ARG_EXPERT}" ]]; then
    for item in "${HOME}"/configs/*.toml; do
      [[ -f "${item}" ]] || continue # handle empty list
      ${CFG_EDITOR:?} "${item}"
    done
  fi

  ############################################
  #Service Files Edit
  ############################################
  #Last edition
  service_edit ""

  #TODO:Update All variables in env files ?

  ############################################
  #Other Edition fo expert mode
  ############################################
  if [[ -n "${ARG_EXPERT}" ]]; then

    #Systemd view if available
    for item in "${HOME}"/.config/systemd/user/*.service; do
      [[ -f "${item}" ]] || continue # handle empty list
      #[ -z "${ARG_EXPERT}" ] && continue
      ${CFG_EDITOR:?} "${item}"
    done

    #Podman config view
    for item in "${HOME}"/.config/containers/*.conf; do
      [[ -f "${item}" ]] || continue # handle empty list
      #[ -z "${ARG_EXPERT}" ] && continue
      ${CFG_EDITOR:?} "${item}"
    done
  fi

  ############################################
  #Final edition changes
  ############################################
  if [[ "${COMMAND}" == "edit" ]]; then
    #Ask user to valid changes
    set_style "yellow"
    if ! yes_or_no_default "y" "Do you confirm settings ?"; then
      echo "Configurations Restored"
      rm -rf "${SERVICE_FOLDER:?}"/*
      cp -pr "${SERVICE_CACHE}"/configs.bak/* "${SERVICE_FOLDER}"
      set_style
      return 1
    fi
    set_style
  fi
  return 0
}

######################################################################################
##################################  ENABLE  ##########################################
######################################################################################
function _user_service_enable() {

  local item
  #Automatic update service
  #systemctl --user enable --now podman-auto-update.timer

  #Enable Services
  for item in "${HOME}"/.config/systemd/user/*.service; do
    [[ -f "${item}" ]] || continue # handle empty list
    systemctl --user enable "$(basename "${item}")" || return 1
  done

  #Start Services
  if [[ -f "${HOME}"/.config/systemd/user/pod-"${CFG_NAME}".service ]]; then
    systemctl --user start "pod-${CFG_NAME}" || return 1
  fi
  for item in "${HOME}"/.config/systemd/user/*.service; do
    [[ -f "${item}" ]] || continue                                                        # handle empty list
    [[ "${item}" == "${HOME}/.config/systemd/user/pod-${CFG_NAME}.service" ]] && continue # handle pod
    systemctl --user start "$(basename "${item}")" || return 1
  done
}
export -f _user_service_enable # export to call as user

function poco_service_enable() {

  loginctl enable-linger "${1}"
  sleep 1 #wait loginctl to launch

  #Enable service
  exec_fn_as_user "${1}" _user_service_enable

}

######################################################################################
##################################  DISABLE  #########################################
######################################################################################
function _user_service_disable() {

  local item
  #Disable service
  if [[ -f "${HOME}"/.config/systemd/user/pod-"${CFG_NAME}".service ]]; then
    systemctl --user --now disable pod-"${CFG_NAME}"
  fi
  for item in "${HOME}"/.config/systemd/user/*.service; do
    [[ -f "${item}" ]] || continue                                                        # handle empty list
    [[ "${item}" == "${HOME}/.config/systemd/user/pod-${CFG_NAME}.service" ]] && continue # handle pod
    systemctl --user --now disable "$(basename "${item}")"
    #systemctl --user stop "$(basename "${item}")"
  done

  #Automatic update service
  #systemctl --user disable --now podman-auto-update.timer

}
export -f _user_service_disable # export to call as user

function poco_service_disable() {

  #Disable Service
  exec_fn_as_user "${1}" _user_service_disable

  loginctl disable-linger "${1}"
}

######################################################################################
##################################  LOGS  ############################################
######################################################################################
function poco_log_service() {

  local item
  #local follow
  #[[ -n ${ARG_FORCE} ]] && follow=-f || follow=""
  if [[ -n $1 ]]; then
    journalctl --user -n 1000 -e -u "$1"
    return 0
  fi
  for item in "${HOME}"/.config/systemd/user/*.service; do
    [[ -f "${item}" ]] || continue                                                        # handle empty list
    [[ "${item}" == "${HOME}/.config/systemd/user/pod-${CFG_NAME}.service" ]] && continue # handle pod
    journalctl --user -n 1000 -e -u "$(basename "${item}")"
  done
}
export -f poco_log_service # export to call as user

######################################################################################
#################################  EVENT  ############################################
######################################################################################

function poco_event() {
  #Call service event
  host_event "${ARG_TYPE}"
}

######################################################################################
###################################  PS  #############################################
######################################################################################
function _title_ps() {
  set_style "white" "underline" >"${TMPFS_PATH}"/infos
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "SERVICE/USER" "STATUS" "HEALTH" "KIND" "HOST" "SIZE" "CREATION" "HOME" "UID/GID" "SUBUID" >>"${TMPFS_PATH}"/infos
  set_style >>"${TMPFS_PATH}"/infos
}

function poco_infos_service() {

  local user=$1
  local home_user
  local uid_gid
  local creation_date
  local service_status
  local service_health
  local service_size
  local service_name
  local service_host

  #Get home directory of the service
  home_user=$(getent passwd "${user}" | cut -d: -f6)
  #UID/GID
  uid_gid="$(id -u "${user}")/$(id -g "${user}")"
  #Get creation date
  creation_date=$(stat -c '%w' "${home_user}")
  #Check if enable
  service_status=$( (_is_service_enable "${user}" && echo "enable") || style_echo "disable" "yellow")
  if ! _is_service_installed "${user}"; then
    service_status=$(style_echo "uninstalled" "red")
  fi
  if [[ "${service_status}" == "enable" ]]; then
    service_health=$( (exec_fn_as_user "${1}" _is_service_started "${user}" && style_echo "started" "green") || style_echo "error" "red")
    #service_count=$( (exec_fn_as_user "${1}" journalctl -b --user -u transmission |grep -c Started) || printf "None" )
  else
    service_health="  -  "
  fi
  #Get Infos
  service_name=$(load_env_value CFG_NAME "${home_user}/configs/service.env")
  service_host=$(load_env_value CFG_HOST "${home_user}/configs/service.env")
  #Get size
  if [[ -z "${ARG_SIZE}" ]]; then
    service_size="  -  "
  else
    IFS=$'\t' read -r -a service_size <<<"$(du -sh "${home_user}" 2>/dev/null)"
  fi
  #Get Subuid
  subuid=$(grep "${user}:" /etc/subuid | cut -d ":" -f2-)

  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "${user}" "${service_status}" "${service_health}" "${service_name}" "${service_host}" "${service_size[0]}" "${creation_date%%.*}" "${home_user}" "${uid_gid}" "${subuid}" >>"${TMPFS_PATH}"/infos

}

function poco_ps() {
  _title_ps
  local item
  for item in "$@"; do
    [[ -n "${item}" ]] || continue # handle empty list
    poco_infos_service "${item}"
  done
  #display
  column -t -s'|' "${TMPFS_PATH}"/infos
}

######################################################################################
################################  STATUS  ############################################
######################################################################################

function poco_status_service() {

  #$1 : user
  ################
  print_separator "-" "blue"
  style_echo "Poco information:" "blue"
  print_separator "-" "blue"
  _title_ps
  poco_infos_service "${1}"
  column -t -s'|' "${TMPFS_PATH}"/infos
  printf "\n"
  ###################################
  #systemd and podman information are unavailable if service is disable
  _is_service_enable "${1}" || return 0
  ###################################
  print_separator "-" "blue"
  style_echo "Podman information:" "blue"
  print_separator "-" "blue"
  if [[ -z "${ARG_SIZE}" ]]; then
    style_echo "CMD: podman ps --all --external --format 'table {{.Image}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}'" "purple"
    exec_fn_as_user "${1}" podman ps --all --external --format "'table {{.Image}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}'"
  else
    style_echo "CMD: podman ps --all --size --external --format 'table {{.Image}}\\t{{.Names}}\\t{{.Size}}\\t{{.Status}}\\t{{.Ports}}'" "purple"
    exec_fn_as_user "${1}" podman ps --all --size --external --format "'table {{.Image}}\\t{{.Names}}\\t{{.Size}}\\t{{.Status}}\\t{{.Ports}}'"
  fi
  printf "\n"
  if [[ -n "${ARG_EXPERT}" ]]; then
    style_echo "CMD: podman stats --all --no-stream --no-reset" "purple"
    exec_fn_as_user "${1}" podman stats --all --no-stream --no-reset
    printf "\n"
    style_echo "CMD: podman ps --all --external --ns" "purple"
    exec_fn_as_user "${1}" podman ps --all --external --ns
    printf "\n"
    mapfile -t container_list < <(exec_fn_as_user "${1}" podman ps --all --external --format '{{.Names}}')
    local item
    for item in "${container_list[@]}"; do
      style_echo "CMD: podman top ${item}" "purple"
      exec_fn_as_user "${1}" podman top "${item}"
      printf "\n"
    done
  fi
  ###################################
  print_separator "-" "blue"
  style_echo "Systemd information: " "blue"
  print_separator "-" "blue"
  style_echo "CMD: systemctl --all --user --no-pager --type=service" "purple"
  #exec_fn_as_user "${1}" systemctl status --user --no-pager #--full
  exec_fn_as_user "${1}" systemctl --all --user --no-pager --type=service
  printf "\n"
  if [[ -n "${ARG_EXPERT}" ]]; then
    style_echo "CMD: systemctl --all --user --type=service list-unit-files" "purple"
    exec_fn_as_user "${1}" systemctl --all --user --type=service list-unit-files
    printf "\n"
    style_echo "CMD: loginctl show-user ${1}" "purple"
    loginctl show-user "${1}"
    printf "\n"
    #style_echo "CMD: systemctl --all --user list-timers" "purple"
    #exec_fn_as_user "${1}" systemctl --all --user list-timers
    #printf "\n"
    #loginctl user-status --no-pager "${1}" #--full
    style_echo "CMD: systemd-analyze --user security" "purple"
    exec_fn_as_user "${1}" systemd-analyze --user security
    printf "\n"
  fi
}

######################################################################################
###############################  VERSION  ############################################
######################################################################################

function poco_version_service() {
  #!! service version tag variable need start CFG_IMAGE
  local home_user
  home_user=$(getent passwd "${1}" | cut -d: -f6)
  sed -n "/^CFG_IMAGE/p" "${home_user}/configs/service.env"
}

######################################################################################
#################################  LOGIN  ############################################
######################################################################################

function poco_login_service() {

  trap - INT ERR SIGTERM SIGTSTP SIGINT
  if [[ -n $1 ]]; then
    local shell=${2:-"sh"}
    su -s /bin/bash --whitelist-environment=XDG_RUNTIME_DIR,DBUS_SESSION_BUS_ADDRESS - "${SERVICE}" \
      -c "podman exec -it $1 ${shell}"
  fi
  su -s /bin/bash --whitelist-environment=XDG_RUNTIME_DIR,DBUS_SESSION_BUS_ADDRESS - "${SERVICE}"
}

######################################################################################
#################################  SETUP  ############################################
######################################################################################
function poco_setup() {

  #Create .bak (group migration service for SERVICE_INSTALLED)
  cp -Tpr "${POCO_CONFIGS:?}" "${TMPFS_PATH}"/poco.conf.bak
  #Edit setting
  ${CFG_EDITOR:?} ${POCO_CONFIGS:?}
  load_env_file "${POCO_CONFIGS}"

  #Create Service Group
  if ! grep -q "${CFG_GROUP:?}" /etc/group; then
    echo "Add '${CFG_GROUP:?}' group service"
    groupadd -g "${CFG_GROUP_GID:?}" "${CFG_GROUP:?}"
    #If old group was set, migrate
    # local user
    # for user in "${SERVICES_INSTALLED[@]}"; do
    #     sudo usermod -a -G "${CFG_GROUP:?}" "${user}"
    # done
    # #TODO: Change permission folder to new group if needed (home service excluded // proc excluded // ...)
    # #Delete old group if exist
    # local old_group
    # old_group=$(load_env_value CFG_GROUP "${TMPFS_PATH}/poco.conf.bak") || :
    # if [[ -n "${old_group}" ]]; then
    #     groupdel "${old_group}"
    # fi
  fi

  #Ask if build podman
  if ! check_podman_installation "${PODMAN_VERSION}" || [[ -n "${ARG_EXPERT}" ]]; then
    style_echo "Podman need be updated/installed" "yellow"
    if yes_or_no "Do you want poco to build and install podman ?"; then
      #Build podman.
      bash "${SPTH:?}"/tools/build-podman.sh --package "${SPTH:?}" v"${PODMAN_VERSION}"
      #Set default policy for registry (WIP)
      podman image trust set --type accept docker.io
      podman image trust set --type accept quay.io
    fi
  fi

  #Create backup directory
  if ! is_relative_path "${CFG_BACKUP_PATH}"; then
    if [[ ! -d "${CFG_BACKUP_PATH}" ]]; then
      set_style "yellow"
      if yes_or_no "'${CFG_BACKUP_PATH}' backup directory don't exist. Do you create it ?"; then
        install -d -m 700 "${CFG_BACKUP_PATH}"
      fi
      set_style
    fi
  else
    log_error "'${CFG_BACKUP_PATH}' must be absolute path"
  fi

  #Don't continue if not expert mode
  if [[ -z "${ARG_EXPERT}" ]]; then
    return 0
  fi

  #Check Sysctl rootless rules
  if [[ ! -f /etc/sysctl.d/20-poco-sysctl.conf ]]; then
    set_style "yellow"
    if yes_or_no "Do you to add sysctl poco configuration ?"; then
      install -m 644 "${SPTH:?}"/20-poco-sysctl.conf -t /etc/sysctl.d/
      sysctl --system
    fi
    set_style
  else
    ${CFG_EDITOR:?} /etc/sysctl.d/20-poco-sysctl.conf
  fi

}

######################################################################################
###################################  MAIN  ###########################################
######################################################################################
function poco_main() {

  case "${COMMAND}" in
  ######################################################################################
  #Command with optional SERVICE
  "ps")
    _control_ps || return 1
    if [[ -z "${ARGS_LIST[0]}" ]]; then
      poco_ps "${SERVICES_INSTALLED[@]}"
    else
      poco_ps "${ARGS_LIST[@]}"
    fi
    return 0
    ;;
  "template")
    _control_template || return 1
    poco_template_main "${ARGS_LIST[@]}"
    return 0
    ;;
  "version")
    _control_version || return 1
    if [[ -z "${ARGS_LIST[0]}" ]]; then
      poco_version
    else
      poco_version_service "${ARGS_LIST[0]}"
    fi
    return 0
    ;;
  "help")
    _control_help || return 1
    if [[ -z "${ARGS_LIST[0]}" ]]; then
      poco_help
    else
      exec_fn_as_user "${ARGS_LIST[0]}" service_help
    fi
    return 0
    ;;
  "setup")
    _control_setup || return 1
    poco_setup
    return 0
    ;;
    ######################################################################################
    #Command with SERVICE
  "install" | "restore")
    _control_install || return 1
    #############################
    local i=1
    while [[ ${i} -le 7 ]]; do
      poco_cmd_install "${i}"
      ((i++))
    done
    ;;

  "uninstall")
    _control_uninstall || return 1
    if ! yes_or_no "Do you want uninstall ${SERVICE} ?"; then
      return 0
    fi
    poco_service_disable "${SERVICE}"
    host_uninstall
    if [[ -z "${ARG_NO_BACKUP}" ]]; then
      backup_service "${SERVICE}" "${ARG_OUTPUT:-"${CFG_BACKUP_PATH}"}"
    fi
    remove_service "${SERVICE}"
    style_echo "Service uninstalled" "green"
    ;;

  "backup")
    _control_backup || return 1
    if _is_service_enable "${SERVICE}"; then
      exec_fn_as_service _user_service_disable
    fi
    backup_service "${SERVICE}" "${ARG_OUTPUT:-"${CFG_BACKUP_PATH}"}"
    if _is_service_enable "${SERVICE}"; then
      exec_fn_as_service _user_service_enable
    fi
    style_echo "Backup for ${SERVICE} done" "green"
    ;;

  "enable")
    _control_enable
    if ! poco_service_enable "${SERVICE}"; then
      log_error "Service enable with error"
      return 1
    fi
    style_echo "Service enable" "green"
    ;;

  "disable")
    _control_disable || return 1
    poco_service_disable "${SERVICE}"
    style_echo "Service disable" "green"
    ;;

  "restart")
    _control_restart || return 1
    exec_fn_as_service _user_service_disable
    if ! exec_fn_as_service _user_service_enable; then
      log_error "Service restarted with error"
      return 1
    fi
    style_echo "Service restarted" "green"
    ;;

  "update")
    _control_update || return 1
    poco_cmd_update
    style_echo "Service updated" "green"
    ;;
  "edit")
    _control_edit || return 1
    poco_cmd_edit
    ;;
  "login")
    _control_login || return 1
    poco_login_service "${ARGS_LIST[@]}"
    ;;
  "logs")
    _control_logs || return 1
    exec_fn_as_service poco_log_service "${ARGS_LIST[@]}"
    ;;
  "status")
    _control_status || return 1
    poco_status_service "${SERVICE}"
    ;;
    ##################################################################################################
    #Not intended to be call by user directly if everything is ok.
  "event")
    _control_event || return 1
    poco_event
    ;;
  *)
    poco_help
    exit 1
    ;;
  esac

}

######################################################################################
################################  VARIABLES  #########################################
######################################################################################
#Command list:
export readonly COMMANDS_LIST=("setup" "install" "logs" "login" "uninstall" "update" "enable" "disable" "restart" "edit" "ps" "status" "help" "version" "template" "backup" "restore" "event")
#Command that can be executed with all or with multiple SERVICE arguments (Warning: that mean no special argument)
export readonly COMMANDS_LIST_ALL=("uninstall" "update" "enable" "disable" "restart" "backup" "event" "status")
#Command that can work without SERVICE argument (Warning: Can't be in NS and ALL command list.)
export readonly COMMANDS_LIST_NS=("ps" "help" "version" "template" "setup" "install" "restore")
#Event list:"
export readonly EVENTS_LIST=("boot" "shutdown" "hibernate" "suspend")
#Reserved name (maybe future use)
export readonly NAME_RESERVED=("exec" "list" "stats" "services" "create" "delete" "remove" "start" "stop" "control" "check" "boot" "change_url" "rename" "upgrade" "health" "purge" "clean" "wake-up")

#Temp folder
TMPFS_PATH=$(mktemp -d "${CFG_TMPFS:?}"/.poco.XXXXXXX)
export readonly TMP_PATH
TMP_PATH=$(mktemp -d "${CFG_TMP:?}"/.poco.XXXXXXX)
export readonly TMPFS_PATH

#Net variable
TLD=$(hostname -d)
DOMAIN_LOCAL="$(hostname -s).${TLD:-lan}"
export readonly TLD
export readonly DOMAIN_LOCAL

#Core
export COMMAND=""
export SERVICE=""

######################################################################################
################################  SCRIPT  ############################################
######################################################################################
#Trap error reset
trap - INT ERR SIGTERM SIGTSTP SIGINT
#Trap on error
trap 'onExitFail ${LINENO}' ERR SIGTERM
#Trap on interrupt: CTRL-Z, CTRL-C
trap 'onExitFail ${LINENO}' SIGTSTP SIGINT
#Trap clean on exit
trap 'onExit' EXIT

#Don't use unset variable Now
#set -u
#: "${COMMAND}"
#: "${SERVICE}"

###########################################################################################
#Parse arguments
poco_parser_main "$@"

###########################################################################################
#Check Special Service name (ALL//all) to allow operation on all containers.
if [[ "${ARGS_LIST[0]}" =~ ^[Aa][Ll][Ll]$ ]]; then
  if ! array_contains COMMANDS_LIST_ALL "${COMMAND}"; then
    log_error "The action execution '${COMMAND}' for 'ALL' is not allowed"
    exit 1
  fi
  set_style "yellow"
  if ! yes_or_no "Do you want '${COMMAND}' for all service ?"; then
    exit 0
  fi
  set_style

  #Remove 'All' service argument. (extra argument can be used by command)
  #ARGS_LIST=("${ARGS_LIST[@]:1}") #shift array

  for i in "${SERVICES_INSTALLED[@]}"; do
    [[ -n "${i}" ]] || continue # handle empty list
    #Logs separator
    print_separator "#" "yellow"
    style_echo "==> Action '${COMMAND}' on '${i}' service." "yellow"
    print_separator "#" "yellow"
    #Update variable
    SERVICE="${i}"
    ARGS_LIST[0]="${SERVICE}"
    #Subshell to avoid variables/function conflict for next iteration
    (
      change_system_variable "${i}"
      source_service
      poco_main || :
    )
  done
  exit 0
fi
###########################################################################################

if ! array_contains COMMANDS_LIST_NS "${COMMAND}"; then
  if [[ -z ${ARGS_LIST[0]} ]]; then
    log_error "The command '${COMMAND}' need a <service> name argument"
    exit 1
  fi
else
  #Command without need a service to run
  poco_main
  exit 0
fi

###########################################################################################

#Check if command can apply to multiple service arguments
if array_contains COMMANDS_LIST_ALL "${COMMAND}"; then
  for i in "${ARGS_LIST[@]}"; do
    #Show separator only if multiple service set by user
    if [[ ${#ARGS_LIST[@]} -gt 1 ]]; then
      print_separator "#" "yellow"
      style_echo "==> Action '${COMMAND}' on '${i}' service." "yellow"
      print_separator "#" "yellow"
    fi
    SERVICE=${i} #Set service name
    if ! is_service_exist "${i}"; then
      continue
    fi
    #Subshell to avoid variables/function conflict for next iteration
    (
      change_system_variable "${i}"
      source_service
      #Call main
      poco_main || :
    )
  done
else
  #One Call
  SERVICE=${ARGS_LIST[0]}         #Get service name
  ARGS_LIST=("${ARGS_LIST[@]:1}") #shift array
  if ! is_service_exist "${SERVICE}"; then
    exit 1
  fi
  change_system_variable "${SERVICE}"
  source_service
  #Call main
  poco_main
fi
