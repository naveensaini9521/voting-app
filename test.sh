#!/bin/bash

check_url() {
    curl -kfsI --max-time 1 "$1" >/dev/null 2>&1 && echo "✅ $2" || echo "❌ $2"
}

while true; do

    # Run all checks in parallel for speed
    check_url "http://votingapp.local" "HTTP Vote" &
    check_url "http://votingapp.local/result" "HTTP Result" &
    check_url "https://votingapp.local" "HTTPS Vote" &
    check_url "https://votingapp.local/result" "HTTPS Result" &
    sleep 1
done