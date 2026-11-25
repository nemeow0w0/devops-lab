#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive


# 1) Install Docker
apt-get update
apt-get install -y docker.io docker-compose-v2


# 2) get the code in github repo
git clone https://github.com/nemeow0w0/devops-lab.git /services/devops-lab
cd /services/devops-lab


# 3) Create .env with a random password
umask 077
echo "PG_PASS=$(openssl rand -hex 16)" > .env

# 4) Run the app
docker compose up -d
