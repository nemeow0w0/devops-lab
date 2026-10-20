#!/bin/bash

#sysinfo.sh - แสดงข้อมูลของเครื่อง

NAME = $(hostname)


echo "=== Server: $NAME ==="
echo "Date:  $(date)"
echo "IP:    $(hostname -I)"
echo "Uptime: $(uptime -p)"
echo "--- Disk ---"
df -h /
