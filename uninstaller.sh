#!/bin/bash

set -e

function identifyDevice()
{
    osName=$(uname -s)

    if [ "$osName" != "Darwin" ]
    then
        echo "macOS only!"
        exit 1
    fi
}

function deleteMacsploit()
{
    echo "Deleting Macsploit"

    for appPath in "/Applications/Macsploit.app" "$HOME/Applications/Macsploit.app"
    do
        if [ -e "$appPath" ] || [ -L "$appPath" ]
        then
            parentFolder=$(dirname "$appPath")

            if [ -w "$parentFolder" ]
            then
                rm -rf "$appPath"
            else
                sudo rm -rf "$appPath"
            fi
        fi
    done
}

function installMacsploit()
{
    echo "Deleting Roblox"

    if [ -e "/Applications/Roblox.app" ]
    then
        sudo rm -rf "/Applications/Roblox.app"
    fi

    echo "Installing Macsploit"

    cd ~/

    macsploitInstaller="$temporaryFolder/macsploit.sh"

    curl -fsSL "https://api.macsploit.dev/main/install.sh" -o "$macsploitInstaller"

    bash "$macsploitInstaller"
}

function installRoblox()
{
    echo "Downloading Roblox"

    curl -fSL --retry 3 --connect-timeout 20 --max-time 900 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15" -sS -o "$diskImage" https://www.roblox.com/download/client?os=mac

    if ! hdiutil imageinfo "$diskImage" >/dev/null 2>&1
    then
        echo "Invalid installer!"
        exit 1
    fi

    mountOutput="$(diskutil image attach "$diskImage" --mountOptions nobrowse --readOnly)"

    while IFS= read -r line
    do
        case "$line" in
            */Volumes/*) rest=${line#*/Volumes}; mountedVolume="/Volumes$rest"; break ;;
        esac
    done <<< "$mountOutput"

    if [ ! -d "$mountedVolume" ]
    then
        echo "Can't open Roblox Installer!"
        exit 1
    fi

    robloxApp="$(find "$mountedVolume" -maxdepth 3 -type d \( -name "Roblox.app" -o -name "RobloxPlayerInstaller.app" \) -print -quit)"
    robloxPkg="$(find "$mountedVolume" -maxdepth 3 -type f -name "*.pkg" -print -quit)"

    if [ -n "$robloxPkg" ]
    then
        echo "Installing Roblox"
        sudo installer -pkg "$robloxPkg" -target /
    elif [ "$(basename "$robloxApp")" = "Roblox.app" ]
    then
        echo "Installing Roblox"
        deleteRoblox
        sudo ditto "$robloxApp" "/Applications/Roblox.app"
    elif [ "$(basename "$robloxApp")" = "RobloxPlayerInstaller.app" ]
    then
        echo "Installing Roblox"
        open -W "$robloxApp"
    else
        echo "Invalid installer!"
        exit 1
    fi

    if [ ! -d "/Applications/Roblox.app" ]
    then
        echo "Couldn't install Roblox!"
        exit 1
    fi
}

function deleteRoblox()
{
    if [ -e "/Applications/Roblox.app" ]
    then
        sudo rm -rf "/Applications/Roblox.app"
    fi
}

function checkStatus()
{
    robloxFolder="/Applications/Roblox.app"
    macsploitFolder="/Applications/Macsploit.app"

    if [ -e "$robloxFolder" ]
    then
        echo "Roblox: Installed"
    else
        echo "Roblox: Not installed"
    fi

    if [ -e "$macsploitFolder" ] || [ -e "$HOME/Applications/Macsploit.app" ]
    then
        echo "Macsploit: Installed"
    else
        echo "Macsploit: Not installed"
    fi

    if [ ! -e "$robloxFolder" ]
    then
        echo "Injected: No"
        return 0
    fi

    bundleName=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$robloxFolder/Contents/Info.plist" 2>/dev/null)

    if [ -z "$bundleName" ]
    then
        bundleName="RobloxPlayer"
    fi

    robloxBinary="$robloxFolder/Contents/MacOS/$bundleName"
    dylibPath="$(find "$robloxFolder/Contents/MacOS" -maxdepth 1 -name "*macsploit*.dylib" -print -quit)"

    if [ ! -e "$robloxBinary" ]
    then
        echo "Injected: No"
        return 0
    fi

    if command -v otool >/dev/null 2>&1
    then
        if otool -L "$robloxBinary" 2>/dev/null | grep -qi "macsploit"
        then
            echo "Injected: Yes"
        else
            echo "Injected: No"
        fi
    else
        if [ -n "$dylibPath" ]
        then
            echo "Injected: Maybe..."
        else
            echo "Injected: No"
        fi
    fi
}

function readChoice()
{
    if [ -t 0 ]
    then
        read -r -p ">>: " choice
    else
        read -r -p ">>: " choice </dev/tty
    fi
}

identifyDevice

temporaryFolder="$(mktemp -d /tmp/roblox.XXXXXX)"
diskImage="$temporaryFolder/Roblox.dmg"
mountedVolume=""

function cleanup()
{
    if [ -n "$mountedVolume" ]
    then
        hdiutil detach "$mountedVolume" -quiet 2>/dev/null || true
    fi

    rm -rf "$temporaryFolder"
}

trap cleanup EXIT

if [ $# -ge 1 ]
then
    choice="$1"
else
    echo "1. Delete MacSploit & Reinstall Roblox"
    echo "2. Delete MacSploit & Roblox"
    echo "3. Delete Roblox"
    echo "4. Install MacSploit"
    echo "5. Check Status"

    readChoice
fi

if [ "$choice" = "1" ]
then
    deleteMacsploit
    installRoblox
elif [ "$choice" = "2" ]
then
    deleteMacsploit
    deleteRoblox
elif [ "$choice" = "3" ]
then
    deleteRoblox
elif [ "$choice" = "4" ]
then
    installMacsploit
elif [ "$choice" = "5" ]
then
    checkStatus
else
    echo "Invalid choice!"
    exit 1
fi

echo "Done"
