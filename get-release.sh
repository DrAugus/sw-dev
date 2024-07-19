#!/bin/bash

# only Windows
# 是 exe 文件
# 如果没有 exe 文件，则下载 zip

print_usage() {
    echo "Usage: $0 [REPO]"
}

if [ ! -n "$1" ]; then
    print_usage
    exit 1
fi

check_jq_lib() {
    # 检查 jq 是否已经安装
    if ! command -v jq &>/dev/null; then
        echo "jq is not installed. Installing jq..."

        # 检查操作系统类型并安装 jq
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # 使用 apt-get 安装 jq (适用于 Debian/Ubuntu)
            if command -v apt-get &>/dev/null; then
                sudo apt-get update
                sudo apt-get install -y jq
            # 使用 yum 安装 jq (适用于 CentOS/RHEL)
            elif command -v yum &>/dev/null; then
                sudo yum install -y jq
            else
                echo "Unsupported Linux distribution."
                exit 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # 使用 brew 安装 jq (用于 macOS)
            if command -v brew &>/dev/null; then
                brew install jq
            else
                echo "Homebrew is not installed. Please install Homebrew first."
                exit 1
            fi
        else
            echo "Unsupported OS type."
            exit 1
        fi

    else
        echo "jq is already installed."
    fi
}

check_jq_lib

is_exe_file() {
    local file_path="$1"
    # 使用 file 命令判断文件类型
    file_type=$(file --mime-type -b "$file_path")

    # 检查文件类型是否为 application/x-dosexec 或其他可能的可执行文件类型
    if [[ "$file_type" == "application/x-dosexec" || "$file_type" == "application/octet-stream" || "$file_type" == "application/vnd.microsoft.portable-executable" ]]; then
        echo "$file_path is a .exe file"
        return 0
    else
        echo "$file_path is not a .exe file"
        return 1
    fi
}

is_zip_file() {
    local file_path="$1"

    # 使用 file 命令判断文件类型
    local file_type=$(file --mime-type -b "$file_path")

    # 检查文件类型是否为 application/zip
    if [[ "$file_type" == "application/zip" ]]; then
        echo "$file_path is a .zip file"
        return 0 # 表示文件是 .zip 文件
    else
        echo "$file_path is not a .zip file"
        return 1 # 表示文件不是 .zip 文件
    fi
}

is_windows_file() {
    local file_path="$1"
    if is_exe_file "$file_path"; then
        return 0
    else
        if is_zip_file "$file_path"; then
            return 0
        fi
    fi
    return 1
}

filename_is_exe() {
    local filename="$1"
    [[ "$filename" == *".exe" ]] && return 0 || return 1
}

filename_is_zip() {
    local filename="$1"
    [[ "$filename" == *".zip" ]] && return 0 || return 1
}

github_repo=$1
latest_release=$(curl -s https://api.github.com/repos/$github_repo/releases/latest)
tag_name=$(echo $latest_release | jq -r '.tag_name')
release_name=$(echo $latest_release | jq -r '.name')
published_at=$(echo $latest_release | jq -r '.published_at')
body=$(echo $latest_release | jq -r '.body')

assets=$(echo $latest_release | jq -r '.assets')
assets_len=$(echo $assets | jq -r length)

check_windows_file_in_assets() {
    local assets="$1"

    if [[ -z "$assets" ]]; then
        echo "No assets found in the latest release."
        return 3
    fi

    # 检查 assets 中是否有以 .exe 结尾的文件
    exe_files=$(echo "$assets" | jq -r '.[] | select(.name | test("\\.exe$")).name')

    if [[ -n "$exe_files" ]]; then
        echo "Found .exe files in assets."
        return 0
    fi

    # 如果没有找到 .exe 文件，检查 assets 中是否有以 .zip 结尾的文件
    zip_files=$(echo "$assets" | jq -r '.[] | select(.name | test("\\.zip$")).name')

    if [[ -n "$zip_files" ]]; then
        echo "Found .zip files in assets."
        return 1
    fi

    echo "No .exe or .zip files found in assets."
    return 2
}

check_windows_file_in_assets "$assets"
result=$?

case $result in
0)
    echo "Exe file found."
    ;;
1)
    echo "Zip file found."
    ;;
2)
    echo "Neither Exe nor Zip files found."
    ;;
3)
    echo "No assets found in the latest release."
    ;;
esac

for i in $(seq 0 $(($assets_len - 1))); do
    asset_url=$(echo $assets | jq -r ".[$i].browser_download_url")
    asset_name=$(echo $assets | jq -r ".[$i].name")
    # download exe or zip
    if (filename_is_exe "$asset_name" && [ $result -eq 0 ]) ||
        (filename_is_zip "$asset_name" && [ $result -eq 1 ]); then
        echo "Downloading $asset_name from $asset_url"
        wget -q $asset_url -O $asset_name
        echo "Downloaded $asset_name"
    fi

done

exit 0

echo "tag_name=$tag_name"
echo "release_name=$release_name"
echo "published_at=$published_at"
echo "body=$body"

exit 0

# echo "tag_name=$tag_name" >> $GITHUB_ENV
# echo "release_name=$release_name" >> $GITHUB_ENV
# echo "published_at=$published_at" >> $GITHUB_ENV
# echo "body=$body" >> $GITHUB_ENV

# echo "Tag Name: ${{ env.tag_name }}"
# echo "Release Name: ${{ env.release_name }}"
# echo "Published At: ${{ env.published_at }}"
# echo "Body: ${{ env.body }}"
