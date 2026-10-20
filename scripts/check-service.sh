#!/bin/bash
set -u

# checkservices is work??


SERVICE=$1

if systemctl is-active --quiet "$SERVICE"; then
    echo "[OK]    $SERVICE is running"
else
    echo "[FAIL] $SERVICE is NOT running"
    exit 1
fi
