#!/usr/bin/env bash
# Pair and connect an Android phone over Wi-Fi (Android 11+), with no ports
# to copy: the phone's pairing and connect ports are discovered via mDNS.
#
# Usage:
#   1. Phone: Settings > Developer options > Wireless debugging >
#      "Pair device with pairing code" (keep that screen open).
#   2. Mac:   bash tool/pair_android.sh   then type the 6-digit code.
set -u
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
[ -x "$ADB" ] || { echo "adb not found at $ADB"; exit 1; }

find_service() { # $1 = mdns service type, prints host:port
  "$ADB" mdns services 2>/dev/null | awk -v t="$1" '$2 == t { print $3; exit }'
}

echo "Looking for the phone's pairing screen (open it now)..."
pair=""
for _ in $(seq 1 180); do
  pair=$(find_service _adb-tls-pairing._tcp)
  [ -n "$pair" ] && break
  sleep 1
done
[ -n "$pair" ] || { echo "No pairing screen found. Open 'Pair device with pairing code' and run again."; exit 1; }

echo "Found pairing service at $pair"
"$ADB" pair "$pair" || { echo "Pairing failed. Check the code and try again."; exit 1; }

echo "Connecting..."
for _ in $(seq 1 20); do
  conn=$(find_service _adb-tls-connect._tcp)
  if [ -n "$conn" ] && "$ADB" connect "$conn" | grep -q "connected"; then
    "$ADB" devices -l
    echo "Connected to $conn"
    exit 0
  fi
  sleep 1
done
echo "Paired, but could not connect yet. Keep Wireless debugging on and run: $ADB devices"
exit 1
