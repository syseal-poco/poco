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
################################## STYLE #############################################
######################################################################################

readonly __End=$'\e[0m'
#control style
readonly __normal='[0'
readonly __bold='[1'
readonly __underline='[4'
readonly __blink='[5'
readonly __reverse='[7'
#foreground color
readonly __black='30'
readonly __red='31'
readonly __green='32'
readonly __yellow='33'
readonly __blue='34'
readonly __purple='35'
readonly __cyan='36'
readonly __white='37'
#background color
readonly ___black='40'
readonly ___red='41'
readonly ___green='42'
readonly ___yellow='43'
readonly ___blue='44'
readonly ___purple='45'
readonly ___cyan='46'
readonly ___white='47'

function style_echo() {
  #$1 : String
  #$2 : Color
  #$3 : ctrl
  if [[ -z "${TERM}" ]]; then
    printf "%s\n" "$1"
    return 0
  fi
  local fg=__${2:-"white"}
  local ctrl=__${3:-"normal"}
  local style=$'\e'"${!ctrl};${!fg}m"
  printf "${style}%s%s\n" "$1" "${__End}"
  return 0
}

function set_style() {
  #$1 : Color
  #$2 : bold/italic
  if [[ -z "${TERM}" ]]; then
    return 0
  fi
  if [[ -z "${1:-""}" ]]; then
    printf "%s" "${__End}"
    return 0
  fi
  local fg=__${1:-"white"}
  local ctrl=__${2:-"normal"}
  local style=$'\e'"${!ctrl};${!fg}m"
  printf "%s" "${style}"
}

function print_separator() {

  #$1 : character
  #$2 : color (if exist)
  #$3 : bold/italic
  set_style "$2" "$3"
  if [[ "${TERM}" == "dumb" ]] || [[ -z "${TERM}" ]]; then
    printf "%0.s$1" {1..80}
  else
    printf '%*s' "${COLUMNS:-$(tput cols)}" '' | tr ' ' "$1"
  fi
  set_style
  printf '\n'
}

######################################################################################
###############################  DEBUG/LOG  ##########################################
######################################################################################

function log_error() {
  style_echo >&2 "[ERR] $1" "red"
}

function log_warn() {
  style_echo >&2 "[WARN] $1" "yellow"
}

#optional log if verbose is set
function log_print() {
  #TODO: Do a better log system
  # if [ -z $_V ]; then
  #     echo "$@"
  # fi
  return 0
}

function log {
  printf "%s\n" "$*"
}

######################################################################################
###############################  FUNCTION  ###########################################
######################################################################################

function displaytime {
  local T=$1
  local D=$((T / 60 / 60 / 24))
  local H=$((T / 60 / 60 % 24))
  local M=$((T / 60 % 60))
  local S=$((T % 60))
  (("${D}" > 0)) && printf '%d days ' ${D}
  (("${H}" > 0)) && printf '%d hours ' ${H}
  (("${M}" > 0)) && printf '%d minutes ' ${M}
  (("${D}" > 0 || "${H}" > 0 || "${M}" > 0)) && printf 'and '
  printf '%d seconds\n' ${S}
}

function onError() {
  style_echo "$(basename "${0%/*}") script error: line $1, '${BASH_COMMAND}'" "red"
}

######################################################################################
###############################  UTILITY   ###########################################
######################################################################################

function fn_exist() {
  [[ $(type -t "$1") == function ]] && return 0 || return 1
}

function user_exist() {
  # $1 : user
  # return 1 if user exist, 0 otherwise
  id -u "$1" >/dev/null 2>&1 && return 0 || return 1
}

function group_exist() {
  #Alt: grep -q -E "^admin:" /etc/group
  getent group "$1" >/dev/null 2>&1 && return 0 || return 1
}

function wait_kill_user_process() {
  # $1 User
  # $2 timeout
  local user=$1
  local time=${2:-30} #default : 30s
  IFS=" " read -r -a list <<<"$(ps -u "${user}" | awk '{if(NR>1) print $1}')"
  if [[ -n ${list[*]} ]]; then
    echo "Wait user PID to end. List: ${list[*]}"
  else
    echo "No process to kill"
    return 0
  fi

  #Kill process after some time
  (
    sleep "${time}"
    loginctl kill-user --signal=9 "${user}"
  ) &
  #Sleep here wait all process to be dead
  local pid
  for pid in "${list[@]}"; do
    [[ -z "${pid}" ]] && continue
    while ps -p "${pid}" >/dev/null; do
      sleep 0.1
    done
  done
  #kill background task, no need to kill now.
  kill %% # or kill %1
  echo "User process killed"
  return 0
}

function yes_or_no {
  #if global variable YES is set, pass the question
  if [[ "${ARG_FORCE}" == "yes" ]]; then
    return 0
  elif [[ "${ARG_FORCE}" == "no" ]]; then
    return 1
  fi
  while true; do
    read -rp "$* [y/n]:" yn
    case ${yn} in
    [OoYy]*) return 0 ;;
    [Nn]*) return 1 ;;
    [Yy][Ee][Ss]*) return 0 ;;
    [Nn][Oo]*) return 1 ;;
    esac
  done
}

function yes_or_no_default {
  #$1 : Default Value
  local default=$1
  shift
  while true; do
    if [[ -z "${ARG_FORCE}" ]]; then
      read -rp "$* [y/n] [Default: ${default}]:" yn
    fi
    local yn=${yn:-${default}}
    case ${yn} in
    [OoYy]*) return 0 ;;
    [Nn]*) return 1 ;;
    [Yy][Ee][Ss]*) return 0 ;;
    [Nn][Oo]*) return 1 ;;
    esac
  done
}

function array_contains() {
  local array="$1[@]"
  local seeking=$2
  local in=1
  local element
  for element in "${!array}"; do
    if [[ ${element} == "${seeking}" ]]; then
      in=0
      break
    fi
  done
  return ${in}
}

function exec_fn_as_user {
  #$1: user
  #$*: command and arguments
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    return 1
  fi
  local user=$1
  shift
  #export sysd variables (podman, systemctl)
  export XDG_RUNTIME_DIR
  export DBUS_SESSION_BUS_ADDRESS
  XDG_RUNTIME_DIR="/run/user/$(id -u "${user}")"
  DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
  su -s /bin/bash "${user}" -c "$*"
}

function generate_ramdom_port_nb {

  #$1: range of port number that can be selected
  local range=${1:-"10000-65535"}
  mapfile -t ports < <(shuf -i "${range}" -n 20)
  local i
  for ((i = 1; i <= 20; i++)); do
    #if one port is used, regenerate entire list
    if ss -tulpn | grep ":${ports[${i} - 1]} "; then
      mapfile -t ports < <(shuf -i "${range}" -n 20)
      i=1
      continue
    fi
    #export a list of random port for user usage
    export "RANDOM_PORT_${i}=${ports[${i} - 1]}"
  done
}

######################################################################################
##################################  SECURITY  ########################################
######################################################################################

#TODO : add more utility to this function (write to files, ...)
function hash_password() {
  # $1 user
  # $2 password
  htpasswd -nb "$1" "$2"
}

function generate_password() {

  #Possibility
  # tr </dev/urandom -dc A-Za-z0-9 | head -c12
  # pwgen -ysBv 20 -N 1
  # openssl rand -hex 20
  # openssl rand -base64 20

  if [[ "$1" == "base64" ]]; then
    openssl rand -base64 20
  elif [[ "$1" == "secret" ]]; then
    openssl rand -hex 20
  elif [[ "$1" == "human" ]]; then
    pwgen -nsBv 20 -N 1
  elif [[ "$1" == "random" ]]; then
    pwgen -ysBv 20 -N 1
  elif [[ "$1" == "sentence" ]]; then
    return 1 #TODO: Generate ramdom sentence
  else
    return 1
  fi
  return 0
}

function verify_password() {
  #$1 type
  #$2 password
  if [[ "$1" == "base64" ]]; then
    return 0
  elif [[ "$1" == "secret" ]]; then
    return 0
  elif [[ "$1" == "human" ]]; then
    if [[ ${#2} -ge 8 && "$2" == *[A-Z]* && "$2" == *[a-z]* && "$2" == *[0-9]* ]]; then
      return 0
    fi
  elif [[ "$1" == "random" ]]; then
    return 0
  else
    return 1
  fi
  return 1
}

######################################################################################
###############################  FILE MANIPULATION  ##################################
######################################################################################
function get_abs_path() {
  #$1: is the path (relative or not)
  #$2: is the  current path
  local path
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    return 1
  fi
  case ${1} in
  /*)
    #Path is absolute
    path="${1}"
    ;;
  *)
    #Path is relative. Transform it.
    path="${2}""/""${1}"
    ;;
  esac
  path="$(realpath -s "${path}" 2>/dev/null)"
  echo "${path}"
  return 0
}

function is_relative_path() {
  #$1: is the path (relative or not)
  if [[ -z "$1" ]]; then
    return 1
  fi
  case ${1} in
  /*)
    #Path is absolute
    return 1
    ;;
  *)
    #Path is relative.
    return 0
    ;;
  esac
  return
}

function add_unique_line() {
  local line_text=$1
  local path_file=$2
  echo "$1 >> $2"
  grep -qxF "${line_text}" "${path_file}" || echo "${line_text}" >>"${path_file}"
}

function edit_conf_files_space() {
  edit_conf_files " " "$@"
}

function edit_conf_files_equal() {
  edit_conf_files "=" "$@"
}

function edit_conf_files() {
  # $1 : assign operand (equal, space)
  # $2 : key
  # $3 : value
  # $n : file(s)

  local assign=$1
  shift 1
  local key=$1
  shift 1
  local value=$1
  shift 1

  #TODO: don't modify comment line

  #sed protect special character from "value" before use command.
  local repl
  repl=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"${value}")
  #sed set variable to each file
  local i
  for i in "$@"; do
    #sed -i "s/#\?\(${key}\s*\).*$/\1${assign}${repl}/g" "${i}"

    #Use variable instead of a temp file to avoid permission restriction on possible folder
    local content
    content="$(sed "s/#\?\(\b${key}\b\s*\).*$/\1${assign}${repl}/g" "${i}")"
    echo "${content}" >"${i}"
  done

}

function load_env_file() {
  local i
  for i in "$@"; do
    if [[ -f "${i}" ]]; then
      set -a
      #shellcheck disable=SC1090
      source "${i}"
      #export $(echo $(sed 's/#.*//g' < "$1"  | xargs) | envsubst)
      set +a
    else
      return 1
    fi
  done
}

#Topic: https://gist.github.com/mihow/9c7f559807069a03e302605691f85572

#Load env file without substitution on value if value got for example '$2'
function load_env_file_raw() {
  local i
  for i in "$@"; do
    if [[ -f "${i}" ]]; then
      set -a
      # shellcheck disable=SC2046
      #export $(sed 's/#.*//g' <"${i}" | xargs)
      export $(grep -vE '^( *)?#' <"${i}" | xargs -d '\n')
      set +a
    else
      return 1
    fi
  done
}

function unload_env_file {
  local i
  for i in "$@"; do
    if [[ -f "${i}" ]]; then
      # shellcheck disable=SC2046
      unset $(grep -v '^#' .env | sed -E 's/(.*)=.*/\1/' | xargs)
    else
      return 1
    fi
  done
}

function load_env_file_raw_prefix() {
  if [[ -f "$1" ]]; then
    set -a
    # shellcheck disable=SC2046
    export $(sed -e 's/#.*//g' <.env | xargs printf -- "${2}%s " | xargs)
    set +a
  else
    return 1
  fi
}

function load_env_value() {
  if [[ -f "$2" ]]; then
    sed -n "s/^${1}=\(.*\)/\1/p" <"${2}"
  else
    return 1
  fi
}

function file_get_content_no_comment() {
  if [[ -f "$1" ]]; then
    sed 's/#.*//g' <"$1"
  else
    return 1
  fi
}

function file_subst_vars {
  #$1 file
  #$@ variable(s) name to replace
  local file=${1}
  shift
  if [[ ! -f "${file}" ]]; then
    echo "This file don't exist."
    return 1
  fi
  #$@ variable(s)
  local i
  for i in "$@"; do
    local name=${i}
    local value=${!i}
    export "${name}=${value}"
    local tmp_var
    tmp_var=$(envsubst "\${${name}}" <"${file}")
    echo "${tmp_var}" >"${file}"
  done
}

function files_subst_env {
  #$@ file(s)
  local var_list
  local tmp_var
  local i
  for i in "$@"; do
    if [[ ! -f "${i}" ]]; then
      echo "This file don't exist."
      return 1
    fi
    var_list="$(grep -E '\${(.*?)}' -o "${i}" || :)" #Get only variable like ${VAR}, not $VAR
    tmp_var=$(envsubst "${var_list}" <"${i}")
    echo "${tmp_var}" >"${i}"
  done
}

function control_username {
  #$1: string to control
  if [[ -z "$1" ]]; then
    return 1
  fi
  #Name too short ?
  if [[ ${#1} -le 3 ]]; then
    return 1
  fi
  #Characters not allowed ?
  local control
  control="$(echo "$1" | tr -dc '[:alnum:]._-')"
  if [[ "$1" != "${control}" ]]; then
    return 1
  else
    return 0
  fi

}
