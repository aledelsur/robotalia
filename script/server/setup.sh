#!/usr/bin/env bash
# One-off setup of a fresh Ubuntu server before the first `bin/kamal setup`. Safe to run again.
#
#   ssh -i ~/.ssh/robotalia_ed25519 root@"$ROBOTALIA_SERVER_IP" 'bash -s' < script/server/setup.sh
#
# It updates the system, disables SSH password login, installs Docker from Docker's apt
# repository (Kamal would otherwise use the get.docker.com convenience script), sets up
# a firewall and adds swap.
set -euo pipefail

# Everything lives in a function: with `bash -s` the script arrives on stdin, which a
# command such as apt-get could otherwise consume.
main() {
  [ "$(id -u)" -eq 0 ] || fail "run this as root"
  [ -s /root/.ssh/authorized_keys ] || fail "root has no authorized SSH key: disabling passwords would lock you out"

  export DEBIAN_FRONTEND=noninteractive

  update_system
  harden_ssh
  install_docker
  configure_firewall
  add_swap

  if [ -f /var/run/reboot-required ]; then
    step "Done. A reboot is required to finish the updates."
  else
    step "Done."
  fi
}

step() { printf '\n==> %s\n' "$*"; }

fail() {
  echo "Error: $*" >&2
  exit 1
}

apt_get() {
  apt-get -y -q -o DPkg::Lock::Timeout=300 -o Dpkg::Options::=--force-confold "$@"
}

update_system() {
  step "Updating the system"
  apt_get update
  apt_get full-upgrade
  apt_get install ca-certificates curl ufw unattended-upgrades
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

harden_ssh() {
  step "Disabling SSH password login"
  # sshd keeps the first value it reads, so this file must sort before any other,
  # such as 50-cloud-init.conf.
  cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
  sshd -t || fail "the new sshd configuration is invalid; nothing was reloaded"

  local effective
  effective="$(sshd -T)"
  grep -qx 'passwordauthentication no' <<< "$effective" || fail "password login is still enabled"
  grep -qx 'kbdinteractiveauthentication no' <<< "$effective" || fail "keyboard-interactive login is still enabled"

  systemctl reload-or-restart ssh
}

install_docker() {
  if command -v docker > /dev/null; then
    step "Docker is already installed: $(docker --version)"
    return
  fi

  step "Installing Docker from Docker's apt repository"
  local codename arch
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  arch="$(dpkg --print-architecture)"
  curl -fsS -o /dev/null "https://download.docker.com/linux/ubuntu/dists/$codename/Release" ||
    fail "Docker publishes no packages for Ubuntu '$codename'"

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt_get update
  apt_get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

# Docker publishes container ports around ufw. The database and Redis stay private
# because config/deploy.yml publishes no ports for them.
configure_firewall() {
  step "Configuring the firewall"
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
}

add_swap() {
  if swapon --show=NAME --noheadings | grep -qx /swapfile; then
    step "Swap is already set up"
    return
  fi

  step "Adding 2 GB of swap"
  [ -f /swapfile ] || fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
}

main "$@" < /dev/null
