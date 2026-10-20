#!/bin/bash
# bootstrap.sh - ตั้งค่า Ubuntu server ใหม่ให้ปลอดภัย
set -euo pipefail

log() {
    echo "[$(date +%H:%M:%S)] $1"
}

update_system() {
    log "Updating system..."
    sudo apt-get update
    sudo apt-get upgrade -y
}

harden_ssh() {
    log "Hardening SSH..."
    if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
        log "ERROR: no SSH key found - refusing to disable password login"
        exit 1
    fi
    echo "passwordauthentication no
permitrootlogin no" | sudo tee /etc/ssh/sshd_config.d/00-hardening.conf > /dev/null
    sudo sshd -t
    sudo systemctl reload ssh
}

setup_firewall() {
    log "Setting up firewall..."
    sudo ufw allow OpenSSH
    sudo ufw --force enable

}

install_tools() {
    log "Installing tools..."
    sudo apt-get install -y htop curl
}

main() {
    update_system
    harden_ssh
    setup_firewall
    install_tools
    log "Done!"
}

main

