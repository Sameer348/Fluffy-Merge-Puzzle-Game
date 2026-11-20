#!/usr/bin/env bash
# Creates the Google Play *upload* keystore and android/key.properties.
# Run it yourself: it asks for passwords, which are never written anywhere
# except your local (git-ignored) key.properties.
#
#   tool/release/make_upload_key.sh [path/to/keystore.jks]
#
# Back the keystore and passwords up somewhere safe (e.g. a password
# manager). With Play App Signing a lost upload key can be reset, but it
# takes a support request and a few days.
set -euo pipefail
cd "$(dirname "$0")/../.."

KEYSTORE="${1:-$HOME/fluffy-merge-upload.jks}"
ALIAS=upload

if [[ -e "$KEYSTORE" ]]; then
  echo "Keystore already exists: $KEYSTORE (not overwriting)" >&2
  exit 1
fi

read -r -s -p "Keystore password (min 6 chars): " STOREPASS; echo
read -r -s -p "Repeat password: " STOREPASS2; echo
[[ "$STOREPASS" == "$STOREPASS2" ]] || { echo "Passwords differ" >&2; exit 1; }

keytool -genkeypair -v \
  -keystore "$KEYSTORE" -storetype PKCS12 \
  -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STOREPASS" -keypass "$STOREPASS"

umask 077
cat > android/key.properties <<PROPS
storeFile=$KEYSTORE
storePassword=$STOREPASS
keyAlias=$ALIAS
keyPassword=$STOREPASS
PROPS
echo "Wrote android/key.properties (git-ignored). Keystore: $KEYSTORE"
