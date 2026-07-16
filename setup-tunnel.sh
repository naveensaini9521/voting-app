#!/bin/bash
# setup-tunnel.sh

sudo pkill -f "minikube tunnel" 2>/dev/null || true
sleep 2

sudo -v
sudo nohup minikube tunnel --cleanup=false > /tmp/minikube-tunnel.log 2>&1 &
sleep 10

if pgrep -f "minikube tunnel" >/dev/null; then
    echo "✅ Tunnel started (PID: $(pgrep -f 'minikube tunnel'))"
else
    echo "❌ Tunnel failed. Check: tail -f /tmp/minikube-tunnel.log"
    exit 1
fi