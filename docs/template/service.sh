#!/bin/bash
#Template to define a service
#Each function are optional. Set them if you need them.

#######################################
# Edit services configurations files
# Commands:
#   install, restore, edit
# Globals:
#   COMMAND
#   SERVICE
# Arguments:
#   $1: file to edit
#######################################
function service_edit {
  return 0
}

#######################################
# Host installation setup
# Commands:
#   install, restore, update
# Globals:
#   COMMAND
#   SERVICE
#   CFG_* from poco and services configs
#######################################
function host_setup {
  return 0
}

#######################################
# Podman service creation
# Commands:
#   install, restore, update
# Globals:
#   COMMAND
#   SERVICE
#   CFG_* from poco and services configs
#######################################
function service_set {

  #Create pod or/and containers here
  # E.g:  podman pod create --hostname "${CFG_NAME}" --name "${CFG_NAME}" -p "${CFG_IP}":"${CFG_PORT}":80
  # E.g:  podman create --pod="${CFG_NAME}" --name="${CFG_NAME}"-app --label "io.containers.autoupdate=registry" \
  #     --env-file "${HOME}/configs/app.env" "${CFG_IMAGE_APP}"
  return 0
}

#######################################
# Service execution called after containers are upped.
# Commands:
#   install, restore, update
# Globals:
#   COMMAND
#   SERVICE
#   CFG_* from poco and services configs
#######################################
function service_exec {

  #E.g:
  # until podman container exists "${CFG_NAME}"-app; do
  #     echo "Container not running, retrying in 10 seconds..."
  #     sleep 10
  # done
  # podman exec "${CFG_NAME}"-app chown -R www-data:www-data /mnt/data
  # ###########################
  # or e.g:
  # podman unshare chown -R www-data:www-data /mnt/data
  return 0
}

#######################################
# Called by host when event occurs
# Commands:
#   event
# Events:
#   boot, shutdown, hibernate, suspend
# Globals:
#   SERVICE
#   CFG_* from poco and services configs
#######################################
function host_event {

  #E.g: Change permissions for gpu card(s) at boot
  #if [[ "$1" == "boot" ]]; then
  #  find /dev/dri -type c -print0 | xargs -0 chmod -v o+rw
  #fi
  return 0
}

#######################################
# Called when service will be uninstalled
# Commands:
#   uninstall
# Globals:
#   SERVICE
#   CFG_* from poco and services configs
#######################################
function host_uninstall {

  return 0
}
