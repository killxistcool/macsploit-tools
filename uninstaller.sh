#!/bin/bash

set -e

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Only works on macOS." >&2
  exit 1
fi

temporary_folder="$(mktemp -d /tmp/roblox.XXXXXX)"
disk_image="$temporary_folder/Roblox.dmg"
mounted_volume=""

clean_up() {
  if [ -n "$mounted_volume" ]; then
    hdiutil detach "$mounted_volume" -quiet 2>/dev/null || true
  fi
  rm -rf "$temporary_folder"
}
trap clean_up EXIT

echo "Deleting MacSploit"

for macsploit_app in \
  "/Applications/Macsploit.app" \
  "$HOME/Applications/Macsploit.app"; do
  if [ -e "$macsploit_app" ] || [ -L "$macsploit_app" ]; then
    if [ -w "$(dirname "$macsploit_app")" ]; then
      rm -rf "$macsploit_app"
    else
      sudo rm -rf "$macsploit_app"
    fi
  fi
done

echo "Installing Roblox"

curl --fail --silent --show-error --location --retry 3 \
  --connect-timeout 20 --max-time 900 \
  --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15" \
  --output "$disk_image" \
  "https://www.roblox.com/download/client?os=mac"

if ! hdiutil imageinfo "$disk_image" >/dev/null 2>&1; then
  echo "Invalid installer!" >&2
  exit 1
fi

mount_output="$(hdiutil attach "$disk_image" -nobrowse -readonly)"
mounted_volume="$(echo "$mount_output" | awk 'index($0, "/Volumes/") { print substr($0, index($0, "/Volumes/")); exit }')"

if [ -z "$mounted_volume" ] || [ ! -d "$mounted_volume" ]; then
  echo "Can't open Roblox Installer!" >&2
  exit 1
fi

roblox_app="$(find "$mounted_volume" -maxdepth 3 -type d -name "Roblox.app" -print -quit)"
roblox_package="$(find "$mounted_volume" -maxdepth 3 -type f -name "*.pkg" -print -quit)"

if [ -n "$roblox_package" ]; then
  sudo installer -pkg "$roblox_package" -target /
elif [ -n "$roblox_app" ]; then
  if [ -e "/Applications/Roblox.app" ]; then
    sudo rm -rf "/Applications/Roblox.app"
  fi
  sudo ditto "$roblox_app" "/Applications/Roblox.app"
else
  echo "Installer doesn't have Roblox app in it!" >&2
  exit 1
fi

if [ ! -d "/Applications/Roblox.app" ]; then
  echo "Couldn't install Roblox!" >&2
  exit 1
fi

clear
