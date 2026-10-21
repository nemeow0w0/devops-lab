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
