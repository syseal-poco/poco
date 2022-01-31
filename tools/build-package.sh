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
  echo "Description: Generate .deb archive"
  echo
  echo "Usage: ./$(basename "$0") <path> <workspace>"
}

######################################################################################
###############################  FUNCTION  ###########################################
######################################################################################
function files_subst_env {
  #$@ file(s)
  for item in "$@"; do
    if [[ -z "${item}" ]]; then
      echo "This file don't exist."
      return 1
    fi
    var_list="$(grep -E '\${(.*?)}' -o "${item}" || :)" #Get only variable like ${VAR}, not $VAR
    tmp_var=$(envsubst "${var_list}" <"${item}")
    echo "${tmp_var}" >"${item}"
  done
}

function yes_or_no {
  #if global variable YES is set, pass the question
  if [[ -n "${ARG_FORCE}" ]]; then
    return 0
  fi
  while true; do
    read -rp "$* [y/n]:" yn
    case ${yn} in
    [OoYy]*) return 0 ;;
    [Nn]*) return 1 ;;
    esac
  done
}

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

OPTIONS="hf"    # ":" mean that the option need arg  # ":hv-:"
LONGOPTS="help" # LONG=verbose,file:

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
  -f)
    ARG_FORCE=true
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

case $2 in
/*)
  WORKSPACE="$2"
  ;;
*)
  WORKSPACE="${CPTH}""/""$2"
  ;;
esac
WORKSPACE="$(realpath -s "${WORKSPACE}")"

#Control folder
if [[ ! -d "${WORKSPACE}" ]]; then
  echo "Workspace don't exist: ${WORKSPACE}"
  exit 1
fi

######################################################################################
################################  SCRIPT  ############################################
######################################################################################
#Control prerequisite
REQUIRED_PKG="dpkg git alien rsync pandoc debhelper"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ${REQUIRED_PKG} | grep "install ok installed")
echo -e "Checking for ${REQUIRED_PKG} :\n${PKG_OK}"
if [[ "" = "${PKG_OK}" ]]; then
  echo "Tools needs : ${REQUIRED_PKG}"
  exit 1
fi

export GIT_VERSION_SHORT
GIT_VERSION_SHORT=$(git describe --abbrev=0 --dirty --always --tags 2>/dev/null)
#GIT_VERSION_LONG=$(git describe --abbrev=6 --dirty --always --tags 2>/dev/null)
#GIT_COMMIT_SHORT=$(git rev-parse --short -q HEAD 2>/dev/null)

#Clear old generation
rm -rf "${PATH_DESTINATION:?}"/poco-*/
#Generation
PACKAGE_PATH=$(mktemp -d "${PATH_DESTINATION}"/poco-"${GIT_VERSION_SHORT}"_XXXXX)

########################################
########## Verification
if [[ -z "${ARG_FORCE}" ]]; then
  echo "--------------------------"
  echo "=> Version : ${GIT_VERSION_SHORT}"
  echo "=> Destination: ${PATH_DESTINATION}"
  echo "=> Workspace: ${WORKSPACE}"
  message="Do you want to continue ?"
  if ! yes_or_no "${message}"; then
    exit 0
  fi
fi

########################################
#change exec directory to workspace directory
cd "${WORKSPACE}"

########################################
#create content folder
mkdir -vp "${PACKAGE_PATH}"
mkdir -vp "${PACKAGE_PATH}/DEBIAN"
mkdir -vp "${PACKAGE_PATH}/etc"
mkdir -vp "${PACKAGE_PATH}/etc/profile.d"
mkdir -vp "${PACKAGE_PATH}/etc/sysctl.d"
mkdir -vp "${PACKAGE_PATH}/opt/poco"
mkdir -vp "${PACKAGE_PATH}/opt/poco/template"
mkdir -vp "${PACKAGE_PATH}/opt/poco/lib"
mkdir -vp "${PACKAGE_PATH}/opt/poco/tools"
mkdir -vp "${PACKAGE_PATH}/lib/systemd/system/"
mkdir -vp "${PACKAGE_PATH}/usr/local/man/man1"
mkdir -vp "${PACKAGE_PATH}/usr/local/bin/"

########################################
#Put debian package configuration
cp -v ./tools/package/{control,conffiles,postinst,preinst,postrm,prerm} "${PACKAGE_PATH}"/DEBIAN
files_subst_env "${PACKAGE_PATH}"/DEBIAN/control

########################################
#Copy all data
cp -rv ./src/template/* "${PACKAGE_PATH}"/opt/poco/template
cp -rv ./src/lib/* "${PACKAGE_PATH}"/opt/poco/lib
cp -v ./src/poco.sh "${PACKAGE_PATH}"/opt/poco/
cp -v ./src/poco-bash-complete.sh "${PACKAGE_PATH}"/etc/profile.d/poco-bash-complete.sh
cp -v ./src/poco-boot.service "${PACKAGE_PATH}"/lib/systemd/system/poco-boot.service
#Copy configurations
cp -v ./src/configs/*.conf "${PACKAGE_PATH}"/opt/poco/
cp -v ./src/configs/20-poco-sysctl.conf "${PACKAGE_PATH}"/etc/sysctl.d/
cp -v ./src/configs/configs.env "${PACKAGE_PATH}"/etc/poco.conf
#Tools used
cp -v ./tools/semver2.sh "${PACKAGE_PATH}"/opt/poco/tools/
cp -v ./tools/build-podman.sh "${PACKAGE_PATH}"/opt/poco/tools/

########################################
#Generate man documentation
pandoc ./docs/poco/poco.1.md -s -t man -o "${PACKAGE_PATH}"/usr/local/man/man1/poco.1

#Generate symlink
ln -vfs /opt/poco/poco.sh "${PACKAGE_PATH}"/usr/local/bin/poco

########################################
#Permission
chmod 600 "${PACKAGE_PATH}"/etc/poco.conf
chmod 600 "${PACKAGE_PATH}"/etc/sysctl.d/20-poco-sysctl.conf
chmod -R u=rwX,g-rwx,o-rwx "${PACKAGE_PATH}"/opt/poco
chmod u=rwX,g=rx,o=rx "${PACKAGE_PATH}"/opt/poco
chmod u=rwX,g=rx,o=rx "${PACKAGE_PATH}"/opt/poco/poco.sh

########################################
#Update version in script file when user want know version
tmp_var=$(envsubst '${GIT_VERSION_SHORT}' <"${PACKAGE_PATH}/opt/poco/poco.sh")
echo "${tmp_var}" >"${PACKAGE_PATH}/opt/poco/poco.sh"
tmp_var=$(envsubst '${GIT_VERSION_SHORT}' <"${PACKAGE_PATH}/usr/local/man/man1/poco.1")
echo "${tmp_var}" >"${PACKAGE_PATH}/usr/local/man/man1/poco.1"

########################################
#Generate debian archive
pushd "${PATH_DESTINATION}"
dpkg -b "${PACKAGE_PATH}" poco-"${GIT_VERSION_SHORT}".deb
#Generate rpm archive
alien --scripts --keep-version --to-rpm poco-"${GIT_VERSION_SHORT}".deb
popd
