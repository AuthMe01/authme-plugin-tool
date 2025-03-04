#!/bin/bash

# Use environment variable VERSION if set, otherwise use default
VERSION=${VERSION:-0.0.1}

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Convert architecture naming
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
else
    echo "不支持的架构: $ARCH"
    exit 1
fi

# Only allow macOS and Linux
if [ "$OS" != "darwin" ] && [ "$OS" != "linux" ]; then
    echo "不支持的操作系统: $OS"
    exit 1
fi

# Define download URL and binary name
BINARY_NAME="authme-plugin-$OS-$ARCH"
DOWNLOAD_URL="https://github.com/AuthMe01/authme-plugin-tool/releases/download/$VERSION/$BINARY_NAME"
echo "下载地址: $DOWNLOAD_URL"

# Set installation directory based on OS
if [ "$OS" = "darwin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    NEED_SUDO=false
else
    INSTALL_DIR="/usr/local/bin"
    # Check if we have write permission to /usr/local/bin
    if [ -w "$INSTALL_DIR" ]; then
        NEED_SUDO=false
    else
        NEED_SUDO=true
    fi
fi

# Create temporary directory for download
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

# Download the binary with error checking
echo "正在下载 $BINARY_NAME..."
if command -v curl >/dev/null 2>&1; then
    if ! curl -L -o "authme-plugin-daemon" "$DOWNLOAD_URL" --fail; then
        echo "错误: 下载失败，检查URL是否正确: $DOWNLOAD_URL"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    # 检查下载的文件大小
    FILE_SIZE=$(stat -f%z "authme-plugin-daemon" 2>/dev/null || stat -c%s "authme-plugin-daemon")
    echo "下载的文件大小: $FILE_SIZE 字节"
    if [ "$FILE_SIZE" -lt 1000 ]; then
        echo "警告: 下载的文件异常小，可能不是有效的二进制文件"
        cat "authme-plugin-daemon" # 显示文件内容以便调试
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -O "authme-plugin-daemon" "$DOWNLOAD_URL"; then
        echo "错误: 下载失败，检查URL是否正确: $DOWNLOAD_URL"
        rm -rf "$TMP_DIR"
        exit 1
    fi
else
    echo "错误: 未安装curl或wget"
    rm -rf "$TMP_DIR"
    exit 1
fi

# 检查文件是否为有效的可执行文件
if ! file "authme-plugin-daemon" | grep -q "executable"; then
    echo "错误: 下载的文件不是有效的可执行文件"
    echo "文件类型:"
    file "authme-plugin-daemon"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Make binary executable
chmod +x "authme-plugin-daemon"

# Install the binary with the new name
if [ "$NEED_SUDO" = true ]; then
    echo "正在安装到 $INSTALL_DIR (需要sudo)..."
    sudo mv "authme-plugin-daemon" "$INSTALL_DIR/authme-plugin"
else
    echo "正在安装到 $INSTALL_DIR..."
    mv "authme-plugin-daemon" "$INSTALL_DIR/authme-plugin"
fi

# Clean up
rm -rf "$TMP_DIR"

# For macOS, ensure ~/.local/bin is in PATH
if [ "$OS" = "darwin" ]; then
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        SHELL_CONFIG=""
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        fi

        if [ -n "$SHELL_CONFIG" ]; then
            echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_CONFIG"
            echo "已将 $INSTALL_DIR 添加到 $SHELL_CONFIG 中的PATH"
            echo "请运行: source $SHELL_CONFIG"
        else
            echo "请将以下行添加到您的shell配置文件中:"
            echo "export PATH=\"\$PATH:$INSTALL_DIR\""
        fi
    fi
fi

echo "安装完成! authme插件已安装到 $INSTALL_DIR/authme-plugin"
echo "验证安装:"
if [ -x "$INSTALL_DIR/authme-plugin" ]; then
    echo "文件存在且可执行"
    "$INSTALL_DIR/authme-plugin" --version || echo "运行版本命令失败"
else
    echo "错误: 安装的文件不存在或不可执行"
fi 