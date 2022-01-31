#!/bin/bash
#

######################################################################################
#################################  INFOS  ############################################
######################################################################################
# square brackets [optional option]
# angle brackets <required argument>
# curly braces {default values}
# parenthesis (miscellaneous info)
function help() {
  echo "Description: Build podman for debian"
  echo
  echo "Usage: ./$(basename "$0") [option] <path> <version>"
}

######################################################################################
###############################  FUNCTION  ###########################################
######################################################################################
function onError() {
  echo "$(basename "$0") script error: line $1, '${BASH_COMMAND}'"
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

#change exec directory to script directory
cd "$(dirname "$0")"
#exit when any command fails
set -eE

#Command
trap 'onError ${LINENO}' ERR #Callback function set when error occur

######################################################################################
################################ GET // OPT ##########################################
######################################################################################
# saner programming env: these switches turn some bugs into errors
#set -o errexit -o pipefail -o noclobber -o nounset

OPTIONS="hpc"                 # ":" mean that the option need arg  # ":hv-:"
LONGOPTS="help,package,clean" # LONG=verbose,file:

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
# shellcheck disable=SC2251
! PARSED=$(getopt --options=${OPTIONS} --longoptions=${LONGOPTS} --name "$0" -- "${SARGS[@]}")

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  # e.g. return value is 1
  #  then getopt has complained about wrong arguments to stdout
  exit 2
fi

# read getopt’s output this way to handle the quoting right:
eval set -- "${PARSED}"

# now enjoy the options in order and nicely split until we see --
while true; do
  case "$1" in
  -h | --help)
    help
    exit 0
    ;;
  -p | --package)
    ARG_PACKAGE=true
    shift
    ;;
  -c | --clean)
    ARG_CLEAN=true
    shift
    ;;
  --)
    shift
    break
    ;;
  *)
    help
    exit 1
    ;;
  esac
done

######################################################################################
#################################  CONTROL  ##########################################
######################################################################################
#handle non-option arguments
if [[ $# -ne 2 ]]; then
  help
  exit 1
fi

#Script need be executed as root
if [[ "${EUID}" -ne 0 ]]; then
  if which sudo &>/dev/null; then
    #Ask privilege if user is not a service.
    cd "${CPTH}"
    sudo "${SCRIPT}" "${SARGS[@]}" || true # ignore failure
    exit 0
  else
    printf "%s\n" "$(basename "${0%/*}") must be run as root."
    exit 1
  fi
fi

#check Path is absolute or not
case $1 in
/*)
  PATH_DESTINATION="$1"
  ;;
*)
  PATH_DESTINATION="${CPTH}""/""$1"
  ;;
esac
PATH_DESTINATION="$(realpath -s "${PATH_DESTINATION}")"

#Control folder
if [[ ! -d "${PATH_DESTINATION}" ]]; then
  echo "Workspace don't exist: ${PATH_DESTINATION}"
  exit 1
fi

PODMAN_VERSION=$2

######################################################################################
################################  SCRIPT  ############################################
######################################################################################
#TODO add fedora version
#TODO: verify installed package if not
if [[ -n "${ARG_PACKAGE}" ]]; then
  apt update && apt upgrade -y

  ##build missing
  apt install make -y

  ##podman
  apt install -y btrfs-progs git golang-go go-md2man \
    iptables libassuan-dev libbtrfs-dev libc6-dev libdevmapper-dev libglib2.0-dev \
    libgpgme-dev libgpg-error-dev libprotobuf-dev libprotobuf-c-dev libseccomp-dev \
    libselinux1-dev libsystemd-dev pkg-config runc uidmap

  ##podman opt
  apt install -y libapparmor-dev
  #TODO: get list of packat missing
  #TODO: uninstall package that was need just for build
fi

mkdir -vp "${PATH_DESTINATION}"
cd "${PATH_DESTINATION}"

if [[ -d "${PATH_DESTINATION}"/podman ]]; then
  cd podman && git fetch
else
  git clone https://github.com/containers/podman/ && cd podman
fi

git checkout "${PODMAN_VERSION}"
make -j"$(nproc)" BUILDTAGS="selinux seccomp systemd apparmor exclude_graphdriver_devicemapper"
make install PREFIX=/usr/local #or /usr
