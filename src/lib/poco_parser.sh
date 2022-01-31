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
################################ GET // OPT ##########################################
######################################################################################

function poco_get_opts {

  ###################################################################
  # saner programming env: these switches turn some bugs into errors
  #set -o errexit -o pipefail -o noclobber -o nounset

  OPTIONS="hefvt:p:o:"                                                                   # ":" mean that the option need arg  # ":hv-:"
  LONGOPTS="help,expert,force,verbose,path:,version,backup,no-backup,output:,type:,size" # LONG=verbose,file:

  ###################################################################
  # -allow a command to fail with !’s side effect on errexit
  # -use return value from ${PIPESTATUS[0]}, because ! hosed $?
  # ! getopt --test > /dev/null
  # if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  #     echo 'I’m sorry, `getopt --test` failed in this environment.'
  #     exit 1
  # fi

  # -regarding ! and PIPESTATUS see above
  # -temporarily store output to be able to check for errors
  # -activate quoting/enhanced mode (e.g. by writing out “--options”)
  # -pass arguments only via   -- "$@"   to separate them correctly
  ! PARSED=$(getopt --options=${OPTIONS} --longoptions=${LONGOPTS} --name "$0" -- "$@")

  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
  fi

  # read getopt’s output this way to handle the quoting right:
  eval set -- "$PARSED"

  # now enjoy the options in order and nicely split until we see --
  while true; do
    case "$1" in
    -h | --help)
      poco_help
      exit 0
      ;;
    --version)
      poco_version
      exit 0
      ;;
    -f | --force)
      export ARG_FORCE=yes
      ARGS_OPT+=("$1")
      shift
      ;;
    -p | --path)
      export ARG_PATH=$2
      ARGS_OPT+=("$1" "$2")
      shift 2
      ;;
    -v | --verbose)
      export ARG_VERBOSE=-v #V for command that use this
      ARGS_OPT+=("$1")
      shift
      ;;
    -e | --expert)           #TODO: Add subcontent: "all","sysd","net","scri", "cfg"
      export ARG_EXPERT=true #TODO: Question if update script to service and  configs file (keep keys already set)
      ARGS_OPT+=("$1")
      shift
      ;;
    --no-backup)
      export ARG_NO_BACKUP=true
      ARGS_OPT+=("$1")
      shift
      ;;
    --backup)
      export ARG_BACKUP=true
      ARGS_OPT+=("$1")
      shift
      ;;
    --size)
      export ARG_SIZE=true
      ARGS_OPT+=("$1")
      shift
      ;;
    -o | --output)
      export ARG_OUTPUT=$2
      ARGS_OPT+=("$1" "$2")
      shift 2
      ;;
    -t | --type)
      export ARG_TYPE="$2"
      ARGS_OPT+=("$1" "$2")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      poco_help
      exit 1
      ;;
    esac
  done

  ARGS_LIST+=("$@")
}

######################################################################################
############################## CONTROL ARGUMENT ######################################
######################################################################################

function _arg_template {

  #Check if template exist
  INSTALL_PATH="${CFG_TEMPLATE_PATH:?}/${1}"
  if [[ ! -d "${INSTALL_PATH}" ]]; then
    log_error "The template service '$1' didn't exist"
    return 1
  fi
}

function _arg_path_install {

  local path

  if path=$(get_abs_path "$1" "${CPTH}"); then
    if [[ -d "${path}" ]]; then
      INSTALL_PATH="${path}"
    elif tar -tzf "${path}" &>/dev/null; then
      control_archive "${path}"
    else
      log_error "The path specified '${ARG_PATH}' is not a directory or an archive"
      exit 1
    fi
  else
    log_error "The path '${ARG_PATH}' don't exist"
    exit 1
  fi
}

function _arg_path_edit {

  local path
  if path=$(get_abs_path "$1" "${CPTH}"); then
    if [[ -d "${path}" ]]; then
      INSTALL_PATH="${path}"
    else
      log_error "The path specified '${ARG_PATH}' is not a directory"
      exit 1
    fi
  else
    log_error "The path '${ARG_PATH}' don't exist"
    exit 1
  fi
}

function control_archive {

  local path=$1
  local dirs
  tar -xf "${path}" --directory "${TMP_PATH}"
  dirs=("${TMP_PATH}"/*/)
  if [[ "${#dirs[@]}" -ne 1 ]]; then
    echo "This tar archive don't seem to be a service"
    rm -r "${TMP_PATH}"
    return 1
  fi

  INSTALL_PATH="${TMP_PATH}"/"$(basename "${dirs[0]}")"

}

function _arg_output {

  local path
  path=$(get_abs_path "$1" "${CPTH}")
  if [[ ! -d "${path}" ]]; then
    log_error "The path specified '${path}' is not a valid directory"
    exit 1
  fi
  ARG_OUTPUT=${path}
}

function control_poco_system {

  #Control permission of general configuration file (only root access)
  IFS=" " read -r -a infos <<<"$(stat -L -c "%a %U %G" "${POCO_CONFIGS:?}")"
  if [[ "${infos[0]}" != "700" ]] || [[ "${infos[1]}" != "root" ]] || [[ "${infos[2]}" != "root" ]]; then
    chown root:root "${POCO_CONFIGS}"
    chmod 700 "${POCO_CONFIGS}"
  fi

}

######################################################################################
############################### CONTROL COMMAND ######################################
######################################################################################
function _control_setup {
  return 0
}

function _control_ps {
  if [[ -z "${ARGS_LIST[0]}" ]]; then
    return 0
  fi
  for i in "${ARGS_LIST[@]}"; do
    if ! is_service_exist "${i}"; then
      return 1
    fi
  done
  return 0
}

function _control_template {
  return 0
}

function _control_version {
  return 0
}

function _control_help {
  return 0
}

######################################################################################

function _control_install {

  #Check if we got argument if install/restore
  declare -i instal_arg=0
  if [[ -n "${ARG_PATH}" ]]; then
    instal_arg+=1
    _arg_path_install "${ARG_PATH}"
  fi
  if [[ -n "${ARG_TYPE}" ]]; then
    instal_arg+=1
    _arg_template "${ARG_TYPE}"
  fi
  if [[ ${instal_arg} != 1 ]]; then
    if [[ ${instal_arg} -gt 1 ]]; then
      log_error "Only one option -t//--type or -p//--path needed"
    else
      log_error "Option -t or -p is required to install/restore a service"
    fi
    exit 1
  fi

  #Get Service name
  if [[ -n "${ARGS_LIST[0]}" ]]; then
    SERVICE=${ARGS_LIST[0]} #Get service name
    #ARGS_LIST=("${ARGS_LIST[@]:1}") #shift array
  else
    SERVICE=$(basename "${INSTALL_PATH}")
  fi

  #Check name is alphanumeric only
  if ! control_username "${SERVICE}"; then
    log_error "Service name fault, only alpha numeric and '.-_' and 4 character minimum"
    exit 1
  fi
  if [[ "${SERVICE}" =~ ^[Aa][Ll][Ll]$ ]] || array_contains NAME_RESERVED "${SERVICE}"; then
    log_error "Service name fault, '${SERVICE}' name is reserved"
    exit 1
  fi

  #Check name is not a command
  if array_contains COMMANDS_LIST "${SERVICE}"; then
    log_error "Service name can't be a command"
    exit 1
  fi
  #Check name is not a event
  if array_contains EVENTS_LIST "${SERVICE}"; then
    log_error "Service name can't be a event"
    exit 1
  fi

  #Check if service name exist
  if array_contains SERVICES_INSTALLED "${SERVICE}"; then
    #Check if install was done correctly
    local home_user
    home_user=$(getent passwd "${SERVICE}" | cut -d: -f6)
    if [[ ! -f ${home_user}/.config/poco/install ]]; then
      log_error "The service '${SERVICE}' is already installed"
      exit 1
    else
      #install in progress, retry possible now
      return 0
    fi
  fi
  if user_exist "${SERVICE}"; then
    log_error "User with '${SERVICE}' name exist"
    exit 1
  fi
  if group_exist "${SERVICE}"; then
    log_error "Group with '${SERVICE}' name exist"
    exit 1
  fi

}

function _control_restore {
  _control_install
}

function _control_uninstall {
  if [[ -n "${ARG_OUTPUT}" ]]; then
    _arg_output "${ARG_OUTPUT}"
  fi
}

function _control_backup {
  if [[ -n "${ARG_OUTPUT}" ]]; then
    _arg_output "${ARG_OUTPUT}"
  fi
}

function _control_enable {
  #Check if the last service to be deactivated is enable
  if _is_service_enable "${SERVICE}"; then
    log_error "Service already enable"
    return 1
  fi
}

function _control_disable {
  #Check if the first service to be activated is disable
  if ! _is_service_enable "${SERVICE}"; then
    log_error "Service already disable"
    return 1
  fi
}

function _control_restart {
  if ! _is_service_enable "${SERVICE}"; then
    log_error "Service is disable, can't restart"
    return 1
  fi
}

function _control_update {
  if ! _is_service_enable "${SERVICE}"; then
    log_error "Service is disable, can't update"
    return 1
  fi
}

function _control_edit {
  if [[ -n "${ARG_PATH}" ]]; then
    _arg_path_edit "${ARG_PATH}"
    if [[ ! -f "${INSTALL_PATH:?}"/service.env ]]; then
      log_error "Missing file: ${INSTALL_PATH}/service.env"
      return 1
    fi
    if [[ ! -f "${INSTALL_PATH:?}"/service.sh ]]; then
      log_error "Missing file: ${INSTALL_PATH}/service.sh"
      return 1
    fi
  fi
  if [[ -n "${ARG_TYPE}" ]]; then
    _arg_template "${ARG_TYPE}"
  fi
}

function _control_login {
  return 0
}

function _control_logs {
  return 0
}

function _control_status {
  return 0
}

function _control_event {
  if ! array_contains EVENTS_LIST "${ARG_TYPE}"; then
    log_error "Event '${ARG_TYPE}' unknown"
    return 1
  fi
  if ! _is_service_enable "${SERVICE}"; then
    log_error "Service '${SERVICE}' is disable"
    return 1
  fi
}

######################################################################################
#############################  ARGUMENT CONTROL  #####################################
######################################################################################

function poco_parser_main {

  #####################################################################################
  #Store getopt argument
  export ARGS_OPT=()
  #Store normal argument
  export ARGS_LIST=()
  #Parser process
  poco_get_opts "$@"

  #####################################################################################
  #Get COMMAND
  if array_contains COMMANDS_LIST "${ARGS_LIST[0]}"; then
    export COMMAND=${ARGS_LIST[0]}
    ARGS_LIST=("${ARGS_LIST[@]:1}") #shift array
  else
    log_error "The command '${ARGS_LIST[0]}' don't exist"
    exit 1
  fi

  #####################################################################################

  #Check if group services exist
  if ! grep -q "${CFG_GROUP}" /etc/group && [[ "${COMMAND}" != "setup" ]]; then
    log_error "${CFG_GROUP}(${CFG_GROUP_GID}) group does not exist, reinstall the application"
    exit 1
  fi
  #Load number of user services installed
  IFS=" " read -r -a SERVICES_INSTALLED <<<"$(getent group "${CFG_GROUP}" | cut -d: -f4 | tr "," " ")"
  export SERVICES_INSTALLED

  #Load variables and function for services load empty one if not declared to avoid error for optional function
  declare_empty_function

  #####################################################################################
  #Control if poco configuration are correctly set.
  if [[ "${COMMAND}" != "setup" ]]; then
    if [[ -z "${CFG_DOMAIN}" ]] || [[ -z "${CFG_GROUP}" ]] || [[ -z "${CFG_GROUP_GID}" ]]; then
      log_error "You need to do 'poco setup' to configure poco"
      exit 1
    fi
  fi

}
