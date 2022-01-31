# ROADMAP

## OUT OF SCOPE

- Kubernetes implementation
- Host systemd services management
- Server cluster deployment

## IDEAS

- [ ] Docs: Examples with systemd services
- [ ] Docs: Examples with compose
- [ ] Core: Rewrite core program in python.
- [ ] Core: Fedora better support
- [ ] Security: SElinux support
- [ ] Security: Secure and sandbox service with systemd. ([Example](https://jellyfin.org/docs/general/administration/installing.html))
- [ ] Usage helpers (user friendly question to help installation of services and construct poco command)
- [ ] Helper for password generation, ssh key generation, certificate self-signed.

## PROJECT

- [ ] Better git/github usage explanation ( Gitflow model, CLI command example)
- [ ] Github labels to organize commit and pull-request
- [ ] Examples and link to templates service
- [ ] CI integration
- [ ] Allow execution without human interaction (Purpose: default full install, automatic tests)
- [ ] Poco Logo/Icon !
- [ ] Reorganize Library (functions names, order, files names, ...)

## RELEASES

### 0.9

- [ ] Review poco setup command.
- [ ] hibernate/shutdown event
- [ ] template command management&
- [ ] Shared folder management command (shared folder between service)

### 1.0

- [ ] Automatic firewall configuration (iptable, ufw ?)
- [ ] Auto-update service daemon (podman) (enable service, add CLI args and update cfg file)
- [ ] Auto-complete command (bash auto-complete)
- [ ] Developper documentation (Template and Architecture)
