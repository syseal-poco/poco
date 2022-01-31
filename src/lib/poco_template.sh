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
##############################  LIST  ################################################
######################################################################################

function poco_template_list() {
  #ls –d "${CFG_TEMPLATE_PATH}"
  #find "${CFG_TEMPLATE_PATH}"/ . -mindepth 1 -maxdepth 1 -type d -name "*" -printf "%f\n" #-ls
  style_echo "Available template list in '${CFG_TEMPLATE_PATH}' folder:" "blue"
  set_style "yellow"
  for d in "${CFG_TEMPLATE_PATH}"/*; do
    [[ -d "${d}" ]] && echo "- $(basename "${d}")"
  done
  set_style
}

######################################################################################
###############################  ADD  ################################################
######################################################################################
function poco_template_add() {
  #$1: path
  local url=$1
  local path
  local name
  local item
  local dest="${TMP_PATH}"/templates
  local template_path_lists

  ###########################################""
  #HTTPS link
  if [[ ${url} == https://* ]]; then
    if [[ ${url} == *.git ]]; then
      git clone --recurse-submodules "${url}" "${dest}"
    elif [[ ${url} == *.tar* ]]; then
      mkdir "${dest}"
      if command -v wget &>/dev/null; then
        wget -P "${dest}" "${url}"
      #elif command -v curl &>/dev/null; then
      else
        return 1
      fi
      tar -xf "${dest}"/*.tar* --directory "${dest}"
    else
      return 1
    fi
    path="${dest}"
  #SSH LINK
  elif [[ ${url} == ssh://* ]]; then
    if [[ ${url} == *.git ]]; then
      git clone --recurse-submodules "${url}" "${dest}"
    else
      return 1
    fi
    path="${dest}"
  #Local Filesystem
  else
    path=$(get_abs_path "${url}" "${CPTH}")
    if [[ ! -d ${url} ]]; then
      return 1
    fi
  fi
  ####################################################################
  ####################################################################

  #Do service search
  mapfile -t template_path_lists < <(find "${path}" -type f -name "service.env" -exec dirname {} \;)

  #Service found
  style_echo "Template list available in '${1}':" "blue"
  for item in "${template_path_lists[@]}"; do
    [[ -z "${item}" ]] && continue #Empty item
    name="$(basename "${item}")"
    if [[ -d "${CFG_TEMPLATE_PATH:?}"/"${name}" ]]; then
      style_echo "- UPD: ${name}" "yellow"
    else
      style_echo "- ADD: ${name}" "green"
    fi
  done
  if ! yes_or_no_default "y" "Do you want add them ?"; then
    return 1
  fi

  #TODO: Check if multiple name in the source folder

  for item in "${template_path_lists[@]}"; do
    [[ -z "${item}" ]] && continue #Empty item
    name="$(basename "${item}")"
    #Remove if exist already
    rm -rf "${CFG_TEMPLATE_PATH:?}"/"${name}"
    cp -r "${item}" "${CFG_TEMPLATE_PATH:?}"
    #permission
    find "${CFG_TEMPLATE_PATH:?}"/"${name}" -type d -exec chmod 700 {} \;
    find "${CFG_TEMPLATE_PATH:?}"/"${name}" -type f -exec chmod 600 {} \;
  done

}

######################################################################################
##############################  REMOVE  ##############################################
######################################################################################
function poco_template_remove() {

  #Check if template exist:
  if [[ ! -d "${CFG_TEMPLATE_PATH:?}"/"$1" ]]; then
    log_error "${CFG_TEMPLATE_PATH}/$1 don't exist"
    return 1
  fi
  #Ask remove
  if yes_or_no_default "y" "Do you want remove '$1' ?"; then
    rm -r "${CFG_TEMPLATE_PATH:?}"/"$1"
  fi

}

######################################################################################
#################################  MAIN  #############################################
######################################################################################

function poco_template_main() {

  local command=$1
  shift
  #Command list:
  readonly COMMANDS_LIST=("create" "list" "add" "rm")

  case "${command}" in
  "create") #TODO: copy template in a specific folder and rename
    return 0
    ;;
  "list")
    poco_template_list
    return 0
    ;;
  "add") #TODO: And update ?
    poco_template_add "$@"
    return 0
    ;;
  "rm")
    poco_template_remove "$@"
    return 0
    ;;
  *)
    log_error "Invalid template command"
    return 1
    ;;
  esac
}
