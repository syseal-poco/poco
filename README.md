# Poco - POdman COnfiguration helper and service manager

## DESCRIPTION

`poco` is as tool to manage web services on a small server or a NAS with high customizability. The tools use **podman** to manage containers and **systemd** to orchestrate deployments. Each service is described in a folder with containers variables, script function and proxy settings.

Each service can be preconfigured to allow the user to deploy quickly. Installation scripts are used to patch containers or the host machine to accommodate the service correctly (Execution during specific events such as startup or shutdown. Command to run inside the container during installation or update,...).

### Features

- Rootless services with dedicated linux user and private network
- Limited user permission for services (Account locked, no history, shell nologin, private home, ...)
- (WIP) Automatic firewall configuration with ufw.
- Multiple installations of the same service possible
- Use native systemd for orchestation. (Generated with podman)
- Default Proxy configuration with Traefik ( 'toml' files )
- Host Configurations and containers patch possible. (function trigged at event like boot, automatic post install command, ...)
- Simple and easy backup (tar) and restore. Easy to use external backup system.

__Service__:

- All-in-One Folder service configuration
- Function helper to interact with user (Ask path, ip address, url, password, ...)
- Host and containers interaction to make service work in special case (device permission, system event )

### Planned

- See [ROADMAP](docs/ROADMAP.md)

## BUILD PACKAGE(S)

- Build package on debian/ubuntu

```bash
cd <project workspace>
apt install -y dpkg git alien rsync pandoc
./tools/build-package.sh ./output ./
```

- Build package with docker or podman

```bash
cd <project workspace>
#Build local image (Note: do it once)
podman build -f build.Containerfile --tag=poco/build-deb .
#Run the container to build package
podman run --rm -v ./:/project  poco/build-deb
```

## INSTALL

```bash
#Send package to host
scp ./output/poco-0.8.0.deb <server>:/tmp/
#Login to the host
ssh <server>
```

### Debian Installation

```bash
#Install with dpkg
sudo dpkg -i /tmp/poco-0.8.0.deb
#if missing package, do this command
sudo apt install -f
#Configure poco
poco setup
```

### Fedora Installation

```bash
#Install with rpm
sudo rpm -i /tmp/poco-0.8.0.noarch.rpm
#Configure poco
poco setup
```

## DESIGN A SERVICE

- (WIP)

## DEVELOPMENT

### Documentation Test

- `pandoc ./docs/poco.1.md -s -t man | /usr/bin/man -l -`

### Create podman container to test poco

```bash
cd <project workspace>
#Create network
sudo podman network create --subnet 10.50.50.0/24 -d bridge poco-network 
```

#### Debian Test

```bash
#Build local image (Note: do it once)
sudo podman build -f test-debian.Containerfile --tag=poco/test/debian ./
#Run the container to test poco
sudo podman run -d -v ./output:/output --privileged --network poco-network --ip 10.50.50.10 --name=poco-debian --hostname=nas.lan poco/test/debian
#Login into the container
sudo podman exec -u=test -it poco-debian bash
```

#### Fedora Test

```bash
#Build local image (Note: do it once)
sudo podman build -f test-fedora.Containerfile --tag=poco/test/fedora ./
#Run the container to test poco
sudo podman run -d -v ./output:/output --privileged --network poco-network --ip 10.50.50.20 --name=poco-fedora --hostname=nas.lan poco/test/fedora
#Login into the container
sudo podman exec -u=test -it poco-fedora bash
```

## History

This project was created in a personal context in order to easily manage my Debian NAS server with services like nextcloud, gitea, ...
At first it was a simple bash script that used docker and docker-compose for the purpose of enabling and disabling services. and some functions to help to install. (Hence the use of shell script today)
With the discovery of podman, I revised my script in order to improve the security of my server with rootless containers and to be able to manage services with more command without using a third-party tool.

## Contributing

Poco is an open project and contribution is very welcome. There are many ways to contribute from simply speaking about your project, through writing examples, improving the documentation, fixing bugs, discuss or implement features.

For a detailed description of contribution opportunities visit the [CONTRIBUTING](docs/CONTRIBUTING.md) file of the documentation.

## Authors, License from external ressources

### Stack Overflow

- The project started with limited knowledge of bash. A lot of information has been retrieved on [Stack Overflow](https://stackoverflow.com/). This message is to thank all the authors for the pieces of code that I have recovered or that I have inspired to code certain functions.

### Externals

- [Bash Style Guide](https://github.com/icy/bash-coding-style#naming-and-styles)
- [Semver2](https://github.com/Ariel-Rodriguez/sh-semversion-2/blob/main/semver2.sh)
