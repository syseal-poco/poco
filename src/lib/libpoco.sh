#!/bin/bash
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
#############################  POCO UTILITY ##########################################
######################################################################################

function check_podman_installation {

  #$1 : Version minimum (semver format)
  if ! command -v podman &>/dev/null; then
    echo "podman is not installed in the system"
    return 1
  fi
  local version
  local regex='(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?'

  version=$(podman --version | grep -Eo "${regex}")

  local answer
  answer=$(sh /opt/poco/tools/semver2.sh "${version}" "${1}")

  if [[ "${answer}" == "-1" ]]; then
    echo "podman version is too low"
    return 1
  fi
  return 0
}

function execute_script_as_service {

  local args
  #Update command
  if [[ -n "$1" ]]; then
    args=("${SARGS[@]}")
    args[-2]="$1" # n-2 argument is the command, n-1 the name
  #No parameters changes, keep originals
  else
    args=("${SARGS[@]}")
  fi
  echo "Execute as user : ${SCRIPT}" "${args[@]}"
  pushd "${CPTH}" || return 1                   #Come back to the current location for relative path usage.
  sudo -u "${SERVICE}" "${SCRIPT}" "${args[@]}" # || true # Ignore failure
  popd || return 1
}

function exec_fn_as_service {
  exec_fn_as_user "${SERVICE}" "$@"
}

function declare_empty_function {

  #(root) Host event (boot,shutdown,hibernate,...)
  fn_exist host_event || {
    host_event() { echo "Function 'host_event' not set, continue"; }
    export -f host_event
  }

  #(root) Host manipulation
  fn_exist host_setup || {
    host_setup() { echo "Function 'host_setup' not set, continue"; }
    export -f host_setup
  }
  fn_exist host_uninstall || {
    host_uninstall() { echo "Function 'host_uninstall' not set, continue"; }
    export -f host_uninstall
  }

  #(user) Containers services
  fn_exist service_set || {
    service_set() { echo "Function 'service_set' not set, continue"; }
    export -f service_set
  }
  fn_exist service_exec || {
    service_exec() { echo "Function 'service_exec' not set, continue"; }
    export -f service_exec
  }
  fn_exist service_help || {
    service_help() { echo "Function 'service_help' not set."; }
    export -f service_help
  }

  #(root) Configuration container edition (pre, post)
  fn_exist service_edit || {
    service_edit() { echo "Function 'service_edit' not set, continue"; }
    export -f service_edit
  }

}

function source_service {

  #Source env(s)
  local i
  for i in "${HOME}"/configs/*.env; do
    [[ -f "${i}" ]] || continue # handle empty list
    load_env_file_raw "${i}"
  done

  #Source functions
  if ! load_env_file "${HOME}"/configs/service.sh; then
    if [[ "${COMMAND}" == "uninstall" ]]; then
      log_warn "Can't load ${HOME}/configs/service.sh"
      return 0
    fi
    log_error "Can't load ${HOME}/configs/service.sh"
    return 1
  fi

}

function is_service_exist {
  #Verify is the service exist is in the group service
  if ! array_contains SERVICES_INSTALLED "${1}"; then
    log_error "The service '${1}' is not installed"
    return 1
  fi
  if ! user_exist "${1}"; then
    log_error "The service exist in '${SERVICES_INSTALLED}' but user '${1}' don't exist"
    return 1
  fi
  if ! group_exist "${1}"; then
    log_error "The service exist in '${SERVICES_INSTALLED}' but group '${1}' don't exist"
    return 1
  fi
  return 0
}

function change_system_variable {

  #Change user and home if needed. "root" account will never be used
  export USER
  export HOME
  USER="${1}"
  HOME=$(getent passwd "${1}" | cut -d: -f6)
  #Utility
  export SERVICE_ENV="${HOME}"/configs/service.env
  export SERVICE_TOML="${HOME}"/configs/service.toml
  export SERVICE_SCRIPT="${HOME}"/configs/service.sh
  export SERVICE_FOLDER="${HOME}"/configs/
  export SERVICE_CACHE="${HOME}"/.config/poco/

  #Set default PWD
  cd "${HOME}" || return 1

}

function onExitFail() {

  #Disable trap
  trap - INT ERR SIGTERM SIGTSTP SIGINT
  #Unset CTRL+C and CTRL+Z
  trap '' SIGINT SIGTSTP

  #For install and restore, uninstall user if possible
  if [[ "${COMMAND}" == "edit" ]]; then
    #restore Backup if edit was cancel or failed
    if [[ -d "${SERVICE_CACHE}"/configs.bak ]]; then
      cp -pr "${SERVICE_CACHE}"/configs.bak/* "${SERVICE_FOLDER}"
    fi
  fi

  #Error message
  if [[ -n "${ARG_VERBOSE}" ]]; then
    log_error "${COMMAND} fail line $1, '${BASH_COMMAND}'"
  fi
  exit 1
}

function onExit() {
  #Clear temp folder if exist
  rm -rf -- "${TMPFS_PATH:?}"
  rm -rf -- "${TMP_PATH:?}"
  #Set default style before exit
  style_echo ""
}

# function onInterrupt() {
#     echo ""
#     if yes_or_no "Do you want abort '${COMMAND}' for '${SERVICE}' ?"; then
#         onExitFail "$@"
#     fi
#     return 0
# }

######################################################################################
###########################  USER/CONTAINERS  ########################################
######################################################################################

function add_service_user() {

  local user=$1
  local home=${2:-"/home"}
  if user_exist "${user}"; then
    echo "user ${user} exist, can't add it."
    return 1
  fi
  echo "user '${user}' creation"
  local homedir="${home}/${user}"
  useradd -m -s /usr/sbin/nologin -d "${homedir}" "${user}"
  #homedir=$(getent passwd "${user}" | cut -d: -f6)
  #Enable systemd services at boot (even if not logged)
  loginctl enable-linger "${user}" #user systemd enable

  #Add systemd variable in ".profile" if admin connect to it (sudo su -s /bin/bash - <service>)
  #If these variables are not set, using command podman will retrieve error
  add_unique_line 'export XDG_RUNTIME_DIR="/run/user/$UID"' "${homedir}"/.profile
  add_unique_line 'export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"' "${homedir}"/.profile

  #Disable login with this account
  passwd -d "${user}" #Delete password
  passwd -l "${user}" #Lock account

  #Disable history
  add_unique_line 'unset HISTFILE' "${homedir}"/.bash_logout
  edit_conf_files_equal HISTFILESIZE 0 "${homedir}"/.bashrc

  #Disable possibility to other users to read home directory.
  chmod -v 700 "${homedir}"
  #Wait loginctl to launch
  sleep 1
}

function backup_service() {
  #$1 : user service
  #$2 : path to backup
  local user=$1
  local output=${2:-"/home"}
  local homedir
  local date
  local main_folder
  local base_folder
  homedir=$(getent passwd "${user}" | cut -d: -f6)
  date=$(date +"%Y%m%d_%H%M%S")
  if [[ -z "${homedir}" ]]; then
    echo "Error when backup, user service don't exist"
    return 1
  fi
  if [[ ! -d "${output}" ]]; then
    echo "Error when backup, destination folder don't exist"
    return 1
  fi
  main_folder=$(dirname "${homedir}")
  base_folder=$(basename "${homedir}")
  #Go to tar folder to allow wildcard pattern to work (expanded by bash)
  pushd "${main_folder}" || return 1

  echo "Tar generation ..."
  #ignore error if *.conf or *.service missing
  tar -cz -C "${main_folder}" -f "${output}"/"${user}"_"${date}".tar.gz \
    "${base_folder}"/.config/containers/*.conf \
    --exclude='.[^/]*' "${base_folder}" || : #-v
  #"${base_folder}"/.config/systemd/user/*.service \
  popd || return 1
  chmod -v 600 "${output}"/"${user}"_"${date}".tar.gz
}

function remove_service() {

  #$1 : user service
  echo "user '$1' deletion"
  local homedir
  homedir=$(getent passwd "$1" | cut -d: -f6)
  #Disable user
  loginctl disable-linger "$1"
  if command -v crontab &>/dev/null; then
    crontab -r -u "$1" || true
  fi
  wait_kill_user_process "$1" 20 || echo "Wait end process fail"
  #Delete user
  rm -rf -- "${homedir:?}"
  userdel "$1" 2>/dev/null
}
