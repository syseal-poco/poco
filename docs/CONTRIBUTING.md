# Contributing

First of all, thank you for taking the time to contribute to this project.

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change.

Please note we have a code of conduct, please follow it in all your interactions with the project.

__Table Of Contents__:

- [Contributing](#contributing)
  - [Code of Conduct](#code-of-conduct)
  - [What should I know before I get started?](#what-should-i-know-before-i-get-started)
    - [Editor / Emacs and package](#editor--emacs-and-package)
    - [Technologie used](#technologie-used)
      - [Information about rootless containers](#information-about-rootless-containers)
      - [Interesting Articles](#interesting-articles)
  - [Pull Request Process](#pull-request-process)
  - [Getting started](#getting-started)
    - [Check out the roadmap](#check-out-the-roadmap)
    - [Documentation](#documentation)
    - [Tests](#tests)
      - [Commands helper when testing](#commands-helper-when-testing)

## Code of Conduct

This project and everyone participating in it is governed by the [Code of Conduct](docs/CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [carbon.severac@tuta.io](mailto:carbon.severac@tuta.io).

## What should I know before I get started?

### Editor / Emacs and package

I invite you to use one of the following editor. The many plugins include tools to analyze and format shell scripts.
This allows you to have an all-in-one tool for the development of poco.

- [VS Code](https://code.visualstudio.com/)
- [VS Codium](https://vscodium.com/)

__Plugin(s)__:

- [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)
- [Git-graph](https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph)
- [TODO-tree](https://marketplace.visualstudio.com/items?itemName=Gruntfuggly.todo-tree)
- [Code spell checker](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker)
- [ShellCheck](https://open-vsx.org/extension/timonwong/shellcheck)
- [shell-format](https://open-vsx.org/extension/foxundermoon/shell-format)
- [Debian](https://marketplace.visualstudio.com/items?itemName=dawidd6.debian-vscode)
- [DotEnv](https://marketplace.visualstudio.com/items?itemName=mikestead.dotenv)
- [Better-toml](https://marketplace.visualstudio.com/items?itemName=bungcip.better-toml)
- [Systemd](https://marketplace.visualstudio.com/items?itemName=coolbear.systemd-unit-file)

__Others__:

- CLI tool: [ShellCheck](https://github.com/koalaman/shellcheck)
- CLI tool: [shfmt](https://github.com/mvdan/sh)
- Website tool: [Command not found](https://command-not-found.com/)
- Website tool: [Regex](https://regex101.com/)

### Technologie used

The main components used by Poco to manage services:

- [Podman](https://podman.io/) is a daemonless container engine for developing, managing, and running OCI Containers on your Linux System. Containers can either be run as root or in rootless mode.

- [Systemd](https://systemd.io/) is a suite of basic building blocks for a Linux system. It provides a system and service manager that runs as PID 1 and starts the rest of the system.

- [Traefik](https://traefik.io/traefik/) is a leading modern reverse proxy and load balancer that makes deploying microservices easy.

#### Information about rootless containers

Poco implements containers in rootless mode. Some operating specifics and problems are listed below.

- [Rootless tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [Shortcomings of Rootless Podman](https://github.com/containers/podman/blob/main/rootless.md)

#### Interesting Articles

Here are some articles from [Redhat sysadmin](https://www.redhat.com/sysadmin/) blog that can help in setting up container on the system and understanding the technical limitations:

- [Rootless podman with nfs](https://www.redhat.com/sysadmin/rootless-podman-nfs)
- [Files devices with podman](https://www.redhat.com/sysadmin/files-devices-podman)
- [Sharing supplemental groups with Podman containers](https://www.redhat.com/sysadmin/supplemental-groups-podman-containers)
- [Running rootless Podman as a non-root user](https://www.redhat.com/sysadmin/rootless-podman-makes-sense)
- [Overlay FS](https://www.redhat.com/sysadmin/podman-rootless-overlay)
- [Configuring container networking](https://www.redhat.com/sysadmin/container-networking-podman)
- [Linux permissions: SUID, SGID, and sticky bit](https://www.redhat.com/sysadmin/suid-sgid-sticky-bit)
- [Systemd: Securing and sandboxing applications and services](https://www.redhat.com/sysadmin/mastering-systemd)

## Pull Request Process

1. Commit code in your feature or fix branch. Note that a branch can have any number of commits.
2. Commits made in the branch only reflect changes on the local machine (i.e. your machine). So, the commits need to be pushed to the remote branch.
3. Then, you’re ready to rebase your branch. Rebasing is required if any new pull requests were merged after you had taken the feature branch.
4. After rebasing, any conflicts that arise need to be resolved, and the code needs to be pushed back to the remote branch.
5. Finally, it’s time to create a pull request.

## Getting started

### Check out the roadmap

I have some functionalities in mind and i have listed them in [ROADMAP](ROADMAP.md). If there is a bug or a feature that is not listed in the **issues** page or there is no one assigned to the issue, feel free to fix/add it! Although it's better to discuss it in the issue or create a new issue for it so there is no conflicting code.

- See [ROADMAP](ROADMAP.md)

### Documentation

Every chunk of code that may be hard to understand has some comments above it. If you write some new code or change some part of the existing code in a way that it would not be functional without changing it's usages, it needs to be documented.

There may be comments or key documentation missing from the source code. Feel free to add them or open a commit on in a pull request.

### Tests

- (WIP)

#### Commands helper when testing

- Process

```bash
#Show service process
top -U <service>
ps -u <service>
htop -u <service>
```

- Network

```bash
#Check open ports
sudo netstat -anutp
sudo ss -utlpn 
#Check Iptable
sudo iptables -S
sudo ip6tables -S
sudo iptables -L -v -n | more
```

- Archive

```bash
#List files in a archives
tar -ztvf archive.tar.gz 
# read specific file
tar -axf archive.tar.gz <service>/configs/service.env  -O  
# Look file depth 1 and depth 2
tar --exclude="*/*" -tf <archive>
tar --exclude="*/*/*" -tf <archive>
```

- Package

```bash
#Check what package installed this.
dpkg -S $(which command)
dpkg -S <config_files>
# Reinstall config file
dpkg --force-confmiss -i <package>
```

- User

```bash
#check user tree and permission
sudo tree -ugp -a -L 3 /home/<service>
#List group of a service
id -nG <service>
#Login as service user
sudo su -s /bin/bash - <service> 
```

- Systemd

```bash
#Systemd usefull command
loginctl user-status
loginctl user-status <user>
systemd-analyze --user security <service>
```
