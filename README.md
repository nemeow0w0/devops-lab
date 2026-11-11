# DevOps Lab

My hands-on journey from fullstack developer to DevOps.

## Stage 1: Linux Server Bootstrap

A Bash script that turns a fresh Ubuntu server into a secured server in one command.

### What it does
- Updates all packages
- Hardens SSH (key-only login, no root login)
- Enables the firewall (ufw) and allows only SSH
- Installs basic tools (htop, curl)

### Usage

```bash
./scripts/bootstrap.sh
```

The script is safe to run many times (idempotent). It stops if no SSH key is
installed, so it never locks me out of the server.

### What I Learned

- **SSH keys:** Key login needs two things: the private key file and its passphrase
  (like an ATM card + PIN). With passwords, anyone who knows the password can log in.
- **Root vs sudo:** Nobody logs in as root directly. Admins use `sudo`, and only users
  in the `sudo` group can use it. A correct password is not enough
  (authentication vs authorization).
- **File permissions:** How `chmod` works (owner / group / others), and why scripts
  need the `x` permission.
- **Bash scripting:** `set -euo pipefail`, exit codes, and why a script should
  fail fast instead of failing silently.
- **Cattle, not pets:** I deleted my server and rebuilt it from zero with this script.

## Stage 2: TinyShop API in Containers

A small Node.js (Express) API that stores items in PostgreSQL. Both run with
Docker Compose on my lab server.

```text
curl ─▶ 127.0.0.1:3355 ─▶ api (Node.js, user "node") ─▶ db:5432 ─▶ PostgreSQL ─▶ volume "pgdata"
        (local only)                                    (not published)        (data survives "down")
```

### Security choices

- **Small, pinned base image:** `node:26-alpine3.24` and `postgres:18.6-alpine3.24`, never `latest`.
- **No npm at runtime:** npm is removed after `npm ci --omit=dev`. The app only needs `node`.
- **Non-root:** the API runs as the `node` user.
- **Database is private:** the `db` service has no published port. Only the API can reach it.
- **Local-only API port:** `127.0.0.1:3355`, because Docker port rules skip the ufw firewall.
- **No secrets in Git:** the database password comes from `.env`, which is in `.gitignore` and `.dockerignore`.
- **Health checks:** the API `/health` runs `SELECT 1`, and the API starts only after the
  database is healthy (`depends_on: condition: service_healthy`).

### Usage

```bash
echo "PG_PASS=$(openssl rand -hex 16)" > .env
chmod 600 .env
docker compose up -d --build

curl 127.0.0.1:3355/health
curl -X POST 127.0.0.1:3355/api/items -H "Content-Type: application/json" -d '{"name":"Monitor","price":4500}'
curl 127.0.0.1:3355/api/items
```

### Backup and restore

```bash
# Backup (stored outside the repo)
docker exec devops-lab-db-1 pg_dump -U shop -d shop --clean --if-exists > ~/backups/shop-$(date +%F).sql

# Restore
docker exec -i devops-lab-db-1 psql -U shop -d shop < ~/backups/shop-YYYY-MM-DD.sql
```

I tested this: backup, delete the volume with `docker compose down -v`, restore, and check the data.

### Vulnerability scan (Trivy)

```bash
trivy image --severity HIGH,CRITICAL tinyshop-api:1.5
```

The first scan found 6 HIGH vulnerabilities. All of them were inside npm, which the app
does not use at runtime. After I removed npm from the image, the scan found 0 HIGH or CRITICAL.

### What I Learned

- **Image vs container:** An image is a read-only package of the app and everything it
  needs. A container is a running copy of an image. Data does not belong in either one.
  It goes in a volume.
- **Dockerfile order:** Files that rarely change (`package.json`, `npm ci`) go before
  files that change often (`server.js`). Then Docker reuses the cache and builds are fast.
- **Smaller images:** A small base image has fewer packages, so it has fewer
  vulnerabilities. Deleting a file in a later `RUN` does not make the image smaller,
  because layers only add.
- **Docker Compose:** A compose file is my `docker run` commands in one file. Services
  talk to each other by name (`db:5432`). `docker compose down -v` deletes the data,
  so I make a backup first.
- **Trivy:** Trivy scans everything inside the image, not only my npm packages. If a
  vulnerability is in something the app does not use, I remove it. If the app uses it,
  I upgrade it. Then I scan again.
