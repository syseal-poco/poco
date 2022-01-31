#!/bin/bash
#
# It will format all project source script files with "shfmt"

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

#change exec directory to script directory
cd "$(dirname "$0")"
#exit when any command fails
set -eE

######################################################################################
######################################################################################

find ../src -name "*.sh" -exec ./shfmt -w -i 2 -ln bash {} \;
find ../tools -name "*.sh" -exec ./shfmt -w -i 2 -ln bash {} \;
