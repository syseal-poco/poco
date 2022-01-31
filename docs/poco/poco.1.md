% POCO(1) poco ${GIT_VERSION_SHORT}
% carbon severac
% January 2022

# NAME

Poco - 'Rootless containers service configuration helper and manager'

# SYNOPSIS

**poco** [*options*] command service ... \
**poco** [*options*] command

# CONFIGURATION

Before to use poco, you need to run at once **'poco setup'**. It will allow you to configure settings and do some
extras installation if needed.

# DESCRIPTION

**poco** is as tool to manage rootless services on a small server or a NAS with high customizability.

# GLOBAL OPTIONS

**\--expert, -e**
: Allow expert mode. That mean you will see more information on status or get the possibility to edit advanced files.

**\--force, -f**
: Force option allow to discard question asked and confirm every question.

**\--type , -t**
: This option is used when user install or restore a service and want use a template by naming it. It specify the event name when event command is called too.

**\--path , -p**
: User provided archive or directory path used when install or restore a service.

**\--output , -o**
: Directory path to store backup when uninstall or backup command is used.

**\--verbose, -v**
: (WIP) Display line and command error if happen.

**\--no-backup**
: Allow uninstall a service without create a backup.

**\--size**
: Display size parameter when using 'poco ps' or 'poco status'

# COMMANDS

## Main Command with a service

| Command     | Description                                                            |
| :---------- | :--------------------------------------------------------------------- |
| `install`   | Install a service from a template, an archive or a path                |
| `restore`   | Install a service from a provided archive or path                      |
| `update`    | Update a service (will disable service before update)                  |
| `uninstall` | Uninstall a service                                                    |
| `enable`    | Enable a service                                                       |
| `disable`   | Disable a service                                                      |
| `restart`   | Restart a service                                                      |
| `edit`      | Edit service configuration files                                       |
| `backup`    | Generate an service archive                                            |
| `login`     | Allow user to login to service or in container service                 |
| `logs`      | Display systemd logs from the services one by one or the specified one |
| `status`    | Display information about the service (poco, podman and systemd)       |

## Command with optional service

| Command    | Description                                                                 |
| :--------- | :-------------------------------------------------------------------------- |
| `setup`    | Setup Poco configuration and do optional installation on the host if needed |
| `ps`       | Show information about all services installed or the services set by user   |
| `help`     | Show poco help or service help is exist                                     |
| `version`  | Show poco version or service containers version                             |
| `template` | Show all template available with poco                                       |

## Special command

| Command | Description                                                               |
| :------ | :------------------------------------------------------------------------ |
| `event` | Used by poco service to trig event like 'boot'. User don't need to use it |

# EXAMPLES

**poco setup**
: Configure poco and do podman installation

**poco version**
: Display version information and exit

**poco help**
: Display the software usage and exit

**poco template list**
: Display template available with poco

**poco ps**
: Display information about all installed services

**poco ps cloud3 flix my_proxy**
: Display information about all installed services mentionned

**poco status nextcloud**
: Display detailled information about nextcloud. Information from poco,podman and systemd.

**poco install -t nextcloud cloud.3**
: Install "cloud.3" service that use 'nextcloud' template

**poco restore -p ./traefik_20210821_110811.tar.gz traefik**
: Install "traefik" service that is restored from tar archive

**poco edit hello**
: Edit 'hello' service and provide updated files ( \*.toml and service.sh ).

**poco edit -p jellyfin myflix**
: Edit 'myflix' service and provide updated files ( \*.toml and service.sh ).

**poco update all**
: Update all services installed

**poco disable web_1 web_2**
: Disable 'web_1' and 'web_2' services

**poco login nextcloud**
: Login to nextcloud service user (allow to do custom command or check as user)

**poco login my_proxy traefik sh**
: Login to 'traefik' container with shell 'sh' in the service 'my_proxy'

**poco logs cloud.3 nextcloud-db**
: Show logs for container 'nextcloud-db' from 'cloud.3' service

# EXIT VALUES

**0**
: Success

**1**
: Error when process

# COPYRIGHT

Copyright (C) 2022 carbon severac

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
