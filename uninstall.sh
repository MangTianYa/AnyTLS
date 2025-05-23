#!/bin/bash

set -e

SERVICE_NAME="mihomo"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONFIG_DIR="/etc/mihomo"
BIN_DIR="/usr/local/bin"
BIN_NAME="mihomo"

echo "开始卸载 AnyTLS ..."

# 1. 停止并禁用 systemd 服务
if systemctl is-active --quiet "$SERVICE_NAME"; then
  systemctl stop "$SERVICE_NAME"
fi
if systemctl is-enabled --quiet "$SERVICE_NAME"; then
  systemctl disable "$SERVICE_NAME"
fi

# 2. 删除 systemd 服务文件
if [ -f "$SERVICE_FILE" ]; then
  rm -f "$SERVICE_FILE"
fi

# 3. 重新加载 systemd 配置
systemctl daemon-reload

# 4. 删除配置目录
if [ -d "$CONFIG_DIR" ]; then
  rm -rf "$CONFIG_DIR"
fi

# 5. 删除 mihomo 可执行文件
if [ -f "$BIN_DIR/$BIN_NAME" ]; then
  rm -f "$BIN_DIR/$BIN_NAME"
fi

echo "AnyTLS 服务及相关文件已全部删除。"
