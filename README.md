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
docker compose up -d

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

## Stage 3: CI Pipeline with GitHub Actions

Every push to `main` runs CI on GitHub. If a step fails, CI stops and nothing is pushed.

```text
push ─▶ Gitleaks ─▶ build ─▶ Trivy ─▶ push to GHCR
```

### Security choices

- **Scan first, push last:** secrets and vulnerable images never reach GHCR.
- **Least privilege:** the token can only read code and push packages.
- **Scan all history:** Gitleaks checks every commit. `--redact` hides secrets in logs.
- **Pin by SHA/digest:** tags can be moved (it happened to Trivy's GitHub Action in March 2026). SHAs can't.
- **No `build:` on the server:** if the image is missing, deploy fails. It never runs an unscanned image.
- **GitHub-hosted runner:** a clean VM every run. No self-hosted runner on a public repo.

### Deploy

Image tag = Git commit SHA.

```bash
# PC: set the new tag in compose.yaml, commit, push
# Server:
git pull
sudo docker compose up -d
```

Rollback: `git revert` the tag commit, push, then run the same 2 commands.
If Trivy fails, there is no image, so it can't be deployed.

### What I Learned

- **CI = my own commands:** run it by hand first, then put it in `run:`.
- **Red tests:** I broke each check on purpose to prove it can fail.
- **Deleted secrets still leak:** they stay in Git history. Rotate them.
- **Tag vs digest:** a tag can move, a digest can't. With a digest, Docker ignores the tag.
- **Read the logs:** the red step isn't always the buggy one. Exit 125 = Docker failed, exit 1 = Trivy found vulns.

## Stage 4: AWS with Terraform

Terraform builds a small, locked-down server on AWS that runs TinyShop, and a private
S3 bucket for database backups. One command creates everything. One command deletes it.

```text
my PC ──ssh :22 (my IP only)──▶ security group ──▶ EC2: Ubuntu 24.04 (Docker: api + db)
my PC ──ssh tunnel──▶ 127.0.0.1:3355 on EC2         (the API is not public)
EC2   ──IAM role: s3:PutObject on backups/* only──▶ S3 bucket (private, files deleted after 7 days)
```

| File | What it creates |
| --- | --- |
| `infra/main.tf` | Security group, SSH key pair, EC2 server |
| `infra/s3.tf` | Backup bucket (public access blocked, 7-day lifecycle) |
| `infra/iam.tf` | IAM role for the server (upload backups only) |
| `infra/user_data.sh` | First-boot script: install Docker, clone this repo, make `.env`, start the app |

### Account safety (before → after)

| Before | After |
| --- | --- |
| Root account used for everything | Daily work as an IAM admin user with MFA. Root has MFA and no access keys. |
| An admin user had a permanent access key | Deleted. There are no permanent keys in the account. |
| CLI used a permanent `AKIA` key | `aws login` gives short-lived credentials. No `credentials` file on my PC. |
| Budget counted credits, so it always showed $0 | Budget shows real spend. Zero-spend and $5 alerts (tested: the email arrived). |

### Security choices

- **SSH from my IP only:** port 22 is open to one IP (`/32`). The IP is a Terraform
  variable, so it is never in Git.
- **API is not public:** it listens on `127.0.0.1:3355`. I use an SSH tunnel. Two layers:
  even if someone opens port 3355 in the security group, nothing listens on the public IP.
- **Least-privilege role:** the server can only upload to `backups/*`. It cannot list, read,
  or delete. A hacker on the server can't steal old backups or delete them (ransomware).
  Old backups are deleted by an S3 lifecycle rule, not by the server.
- **No keys on the server:** the role gives short-lived credentials. IMDSv2 is required,
  which blocks SSRF attacks that steal role credentials (like Capital One in 2019).
- **Secrets are made on the server:** `user_data` is not secret (it shows in the plan, the
  state file, and the AWS console). So the database password is created on the server
  with `openssl rand`, saved with `umask 077`, and never printed (`set -x` is off).
- **Encrypted disk** and a **trusted image** (Ubuntu from Canonical's owner ID only).
- **Private bucket:** all 4 public access blocks are on. The name has a random suffix.
- **State file:** it holds sensitive data in plain text, so it is in `.gitignore` and
  `chmod 600`.
- **No surprise bills:** `cpu_credits = "standard"`, budget alerts, and I destroy
  everything after each lab.

### Usage

```bash
aws login --remote
export TF_VAR_my_ip="$(curl -s https://checkip.amazonaws.com)/32"
echo $TF_VAR_my_ip

terraform init
terraform plan        # expect: 11 to add
terraform apply
ssh -i ~/.ssh/aws-lab ubuntu@$(terraform output -raw public_ip) cloud-init status --wait

# Terminal 2: open the tunnel and keep it open
ssh -i ~/.ssh/aws-lab -N -L 3355:127.0.0.1:3355 ubuntu@$(terraform output -raw public_ip)
# Terminal 1:
curl 127.0.0.1:3355/health

terraform destroy     # expect: 11 destroyed
```

After `destroy`, I also ask AWS directly that no instances, volumes, or buckets are left.

### Tests I ran

| Test (on the server) | Expected | Result |
| --- | --- | --- |
| Who am I? | assumed role, no keys on disk | ✅ |
| Upload to `backups/` | allowed | ✅ |
| Upload to `other/` | AccessDenied | ✅ |
| List the bucket | AccessDenied | ✅ |
| Read a backup | 403 Forbidden | ✅ |
| Delete a backup | AccessDenied | ✅ |
| Call the EC2 API | UnauthorizedOperation | ✅ |
| IMDSv1 (no token) | 401 | ✅ |
| Public IP, port 3355 (from my PC) | timeout | ✅ |

Backup and restore check:

```bash
# On EC2: back up straight to S3 (no file on the disk)
sudo docker compose exec -T db pg_dump -U shop shop | gzip | aws s3 cp - s3://$B/backups/shop-$(date +%F-%H%M).sql.gz

# On my PC (admin): the backup has my test row
aws s3 cp s3://$B/backups/shop-YYYY-MM-DD-HHMM.sql.gz - | gunzip | grep backup-test
```

I rebuilt everything from an empty folder two times: once with notes, once from memory.

### What I Learned

- **Terraform = blueprint + notebook:** `.tf` files say what I want. The state file remembers
  what exists. Terraform only knows what is in state, so after `destroy` I still check AWS.
- **`validate` is not enough:** it can't catch wrong text like `"Services"` or
  `ec2.amazonaws.com0`. My tests caught them.
- **Read the error:** `Connection timed out` = the security group blocked me.
  `Permission denied (publickey)` = I reached the server, but the key is wrong.
- **Fail for the right reason:** a test that fails with `NoSuchBucket` is not a pass. It must
  fail with `AccessDenied` to prove the policy works.
- **IAM role = staff badge:** trust policy (who can wear it) + permission policy (which doors
  it opens) + instance profile (the lanyard that puts it on EC2).
- **Real problems happen:** my home IP changed in the middle of a lab. I updated the variable,
  and `apply` changed only one rule (`1 to change`).
- **A backup you never restored is not a backup.**
