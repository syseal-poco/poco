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
######################################################################################
######################################################################################
#TODO: source poco code to get command list

function _poco() {

  # declare -i length
  # length=${#COMP_WORDS[@]}

  # if [ "$length" -le 2 ]; then
  #     COMPREPLY=("${COMMANDS_LIST[@]}")
  # else
  #     COMPREPLY=("nope")
  # fi
  #   if [ "${#COMP_WORDS[@]}" != "2" ]; then
  #     return
  #   fi

  #   # keep the suggestions in a local variable
  #   local suggestions=($(compgen -W "${COMMANDS_LIST[@]}" -- "${COMP_WORDS[1]}"))

  #   if [ "${#suggestions[@]}" == "1" ]; then
  #     # if there's only one match, we remove the command literal
  #     # to proceed with the automatic completion of the number
  #     local number=$(echo ${suggestions[0]/%\ */})
  #     COMPREPLY=("$number")
  #   else
  #     # more than one suggestions resolved,
  #     # respond with the suggestions intact
  #     COMPREPLY=("${suggestions[@]}")
  #   fi

  return 0
}

complete -F _poco poco
