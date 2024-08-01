#!/bin/bash

print_usage() {
    echo "Usage: $0 [ASSET]"
}

if [ ! -n "$1" ]; then
    print_usage
    exit 1
fi

asset_name=$1
asset_url=""

echo "get $asset_name"
case $asset_name in
"ffmpeg")
    asset_url="https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z"
    extension=$(echo "$asset_url" | awk -F'.' '{print $NF}')
    asset_name=$asset_name.$extension
    echo ">>> get $asset_name from $asset_url"
    wget -q $asset_url -O $asset_name
    ;;
*)
    echo "Sorry, your asset $asset_name is not listed."
    ;;
esac
