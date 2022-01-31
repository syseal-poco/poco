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
############################# SERVICE UTILITY ########################################
######################################################################################
function basic_management {
  return 0 #TODO: ask some text
}

## Type, Key, file1, file2 , ...
function ask_password_helper {

  local type=$1
  shift 1
  local name=${1}
  local password=${!1}
  shift 1

  #If the password is not empty, not need to change
  if [[ -n "${password}" ]]; then
    return 0
  fi

  echo "Password need to be set for ${name}"
  while true; do
    if yes_or_no "Generate password (${type}) ?"; then
      # generate_password
      password=$(generate_password "${type}")
      break
    else
      echo "Enter a \"${type}\" password for ${name}."
      echo "Minimum 8 character, one number, one upper case, one lower case."
      echo
      read -r -s -p "Password: " password
      if verify_password "${type}" "${password}"; then
        read -r -s -p "Password (again): " password2
        if [[ "${password}" = "${password2}" ]]; then
          break
        else
          echo "Password are not the same"
        fi
      else
        echo "Password: min 8 char, a upper and lower case and a number"
      fi
      echo "Please try again"
    fi
  done

  #Update the variable
  set -a
  export "${name}=${password}"
  set +a

  #Update File if needed
  local i
  for i in "$@"; do
    edit_conf_files_equal "${name}" "${password}" "${i}"
  done

  print_separator '-' 'blue'
  style_echo "Key: ${name}" "blue"
  style_echo "Pwd: ${password}" "blue"
  print_separator '-' 'blue'

}

## Key, file1, file2 , ...
function ask_email_helper {

  local name=${1}
  local email=${!1}
  shift 1
  #email Regex
  local regex="^(([-a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~]+|(\"([][,:;<>\&@a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~-]|(\\\\[\\ \"]))+\"))\.)*([-a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~]+|(\"([][,:;<>\&@a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~-]|(\\\\[\\ \"]))+\"))@\w((-|\w)*\w)*\.(\w((-|\w)*\w)*\.)*\w{2,4}$"

  #If the email is not empty, not need to ask if it is a good format.
  if [[ -n "${email}" ]]; then
    if [[ ! ${email} =~ ${regex} ]]; then
      echo "Email set for ${name} is wrong: ${email}"
    else
      echo "Email set for ${name} is good"
      return 0
    fi
  else
    echo "Address email need to be set for ${name}"
  fi

  while true; do
    read -r -p "Email: " email
    if [[ ! ${email} =~ ${regex} ]]; then
      echo "Wrong email, retype"
      continue
    fi
    if yes_or_no "Are you sure ? (${email})"; then
      break
    fi
    echo "Please retype again"
  done

  #Update the variable
  set -a
  export "${name}=${email}"
  set +a

  #Update File if needed
  local i
  for i in "$@"; do
    edit_conf_files_equal "${name}" "${email}" "${i}"
  done
}

function ask_ip_cidr_helper {

  local name=${1}
  local address=${!1}
  shift 1

  local n='([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
  local m='([0-9]|[12][0-9]|3[012])'

  #If the address is not empty, not need to ask if it is a good format.
  if [[ -n "${address}" ]]; then
    if ! [[ ${address} =~ ^${n}(\.${n}){3}/${m}$ ]]; then
      echo "CIDR IP set for ${name} is wrong: ${address}"
    else
      echo "CIDR IP set for ${name} is good"
      return 0
    fi
  else
    echo "Address ip (cidr) need to be set for ${name}"
  fi

  while true; do
    IFS= read -rp 'Address: ' address
    if ! [[ ${address} =~ ^${n}(\.${n}){3}/${m}$ ]]; then
      echo "Wrong CIDR ip format, retype"
      continue
    fi
    if yes_or_no "Are you sure ? (${address})"; then
      break
    fi
    echo "Please retype again"
  done

  #Update the variable
  set -a
  export "${name}=${address}"
  set +a

  #Update File if needed
  local i
  for i in "$@"; do
    edit_conf_files_equal "${name}" "${address}" "${i}"
  done
}

## Key, type, file1, file2 , ...
function ask_path_helper {

  local type=$1 #folder // file
  shift 1
  local name=${1}
  local path=${!1}
  shift 1

  #TODO: control if path as good permission for user
  #TODO: Ask user if he want abort gracefully

  #If the path is not empty, not need to ask.
  if [[ -n "${path}" ]]; then
    if [[ -d "${path}" ]] && [[ "${type}" == "folder" ]]; then
      echo "Folder set for ${name} is good"
      return 0
    elif [[ -f "${path}" ]] && [[ "${type}" == "file" ]]; then
      echo "File set for ${name} is good"
      return 0
    else
      echo "Path for ${name} is wrong (${path})"
    fi
  else
    echo "Path need to be set for ${name}"
  fi

  #TODO: Add possibility to create folder
  #TODO: Add a way to select user//group and permission affiliated with the folder
  #TODO: Create group if don't exist

  echo "Current path: ${PWD}"
  while true; do
    read -e -r -p "Path: " path
    if [[ ! -d "${path}" ]] && [[ "${type}" == "folder" ]]; then
      echo "Folder don't exist"
      if yes_or_no "Do you want create it ?"; then
        mkdir -vp "${path}"
        chown "${SERVICE}":"${SERVICE}" "${path}"
        break
      fi
      continue
    elif [[ ! -f "${path}" ]] && [[ "${type}" == "file" ]]; then
      echo "File don't exist"
      continue
    fi
    path="$(realpath -s "${path}")" #can need root
    if yes_or_no "Are you sure ? (${path})"; then
      break
    fi
    echo "Please retype again"
  done
  echo ""

  #Update the variable
  set -a
  export "${name}=${path}"
  set +a

  #Update File if needed
  local i
  for i in "$@"; do
    edit_conf_files_equal "${name}" "${path}" "${i}"
  done
}

######################################################################################
############################## CONTROL UTILITY #######################################
######################################################################################
function is_port_used {
  #$1 type
  #$# port

  local type
  if [[ "${1}" == "udp" ]]; then
    type=u
  elif [[ "${1}" == "tcp" ]]; then
    type=t
  else
    log_error "Unknown type"
    return 1
  fi
  shift 1 # Other information are port(s)

  local i
  for i in "$@"; do
    #Add ':' if not present
    if ! [[ ${i} == :* ]]; then
      i=":"${i}
    fi
    if command -v ss &>/dev/null; then
      if ss -${type} -lpn | grep "${i} "; then
        log_error "Port (${i}) already used !"
        return 1
      fi
    else
      if netstat -${type} -anp | grep "${i} "; then
        log_error "Port (${i}) already used !"
        return 1
      fi
    fi
  done

}

######################################################################################
############################### PROXY UTILITY ########################################
######################################################################################
function check_string_domain {

  local regex='^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$'

  if echo "$1" | grep -qoP "${regex}"; then
    #"$1 is a domain"
    return 0
  fi
  #"$1 is not a domain"
  return 1

}

function traefik_change_password() {
  # $1 : account
  # $2 : value
  # $n : file(s)
  local account=$1
  shift 1
  local value=$1
  shift 1

  local repl
  local content
  #sed protect special character from "value" before use command.
  repl=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"${value}")
  #sed set variable to each file
  local i
  for i in "$@"; do
    if [[ ! -f ${i} ]]; then
      return 1
    fi
    #Use variable instead of a temp file to avoid permission restriction on folder that contain the file
    content="$(sed "s|\"${account}:\(.*\)\"|\"${repl}\"|g" "${i}")"
    echo "${content}" >"${i}"
  done

}

function traefik_change_host() {
  # $1 : host
  # $n : file(s)
  local host=$1
  shift 1

  local repl
  local content
  #sed protect special character from "host" before use command.
  repl=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"${host}")
  #sed set variable to each file
  local i
  for i in "$@"; do
    if [[ ! -f ${i} ]]; then
      return 1
    fi
    #Use variable instead of a temp file to avoid permission restriction on folder that contain the file
    content="$(sed "s|\"Host(\`\(.*\)\`)\"|\"Host(\`${repl}\`)\"|g" "${i}")"
    echo "${content}" >"${i}"
  done

}
