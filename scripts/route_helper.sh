#!/bin/bash
# TunnelGuard Route Helper
# This script is called by TunnelGuard to manage routing rules.
# It requires sudo privileges. Configure /etc/sudoers to allow
# passwordless execution for route commands.
#
# Add this to /etc/sudoers using `sudo visudo`:
#   %admin ALL=(ALL) NOPASSWD: /sbin/route

ACTION=$1
IP=$2
GATEWAY=$3

case "$ACTION" in
  add)
    if [ -z "$IP" ] || [ -z "$GATEWAY" ]; then
      echo "Usage: route_helper.sh add <IP> <GATEWAY>"
      exit 1
    fi
    sudo /sbin/route -n add "$IP" "$GATEWAY" 2>&1
    ;;
  delete)
    if [ -z "$IP" ]; then
      echo "Usage: route_helper.sh delete <IP>"
      exit 1
    fi
    sudo /sbin/route -n delete "$IP" 2>&1
    ;;
  list)
    netstat -nr | grep -v ':' | head -40
    ;;
  gateway)
    netstat -nr | grep default | grep -v ':' | head -1 | awk '{print $2}'
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Available: add, delete, list, gateway"
    exit 1
    ;;
esac
