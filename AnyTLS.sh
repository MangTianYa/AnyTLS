#!/bin/bash

set -e

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本"
  exit 1
fi

echo "开始安装 AnyTLS..."

# 验证端口是否合法函数
is_valid_port() {
  local port=$1
  if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
    return 0
  else
    return 1
  fi
}

# 检查端口是否被占用函数
is_port_in_use() {
  local port=$1
  if ss -tuln | grep -q ":$port\b"; then
    return 0
  else
    return 1
  fi
}

# 获取 IP 函数
get_ip() {
    local ip=""
    ip=$(ip -o -4 addr show scope global | awk '{print $4}' | cut -d'/' -f1 | head -n1)
    [ -z "$ip" ] && ip=$(curl -4 -s --connect-timeout 3 ifconfig.me 2>/dev/null || curl -4 -s --connect-timeout 3 icanhazip.com 2>/dev/null)
    if [ -z "$ip" ]; then
        read -p "未能获取公网 IP，请手动输入: " ip
    fi
    echo "$ip"
}

# 2. 交互获取参数（带默认值，验证端口）
DEFAULT_PORT=1443
DEFAULT_USER_CREDENTIAL="xR3fd10H:6cdiG9f1b6jo"
DEFAULT_CERT_CN="genshin.hoyoverse.com"

while true; do
  read -p "请输入端口（默认: $DEFAULT_PORT）: " ANYTLS_PORT
  ANYTLS_PORT=${ANYTLS_PORT:-$DEFAULT_PORT}
  if ! is_valid_port "$ANYTLS_PORT"; then
    echo "端口号不合法，请输入1-65535之间的数字"
    continue
  fi
  if is_port_in_use "$ANYTLS_PORT"; then
    echo "端口 $ANYTLS_PORT 已被占用，请换一个端口"
    continue
  fi
  break
done

read -p "请输入用户凭据（格式 username:password，默认: $DEFAULT_USER_CREDENTIAL）: " USER_CREDENTIAL
USER_CREDENTIAL=${USER_CREDENTIAL:-$DEFAULT_USER_CREDENTIAL}

read -p "请输入证书域名（默认: $DEFAULT_CERT_CN）: " CERT_CN
CERT_CN=${CERT_CN:-$DEFAULT_CERT_CN}

# 拆分用户名和密码
USER=$(echo "$USER_CREDENTIAL" | cut -d':' -f1)
PASSWORD=$(echo "$USER_CREDENTIAL" | cut -d':' -f2)

# 3. 安装必要工具
apt update && apt install -y wget curl unzip openssl

# 4. 下载 mihomo 并解压
DOWNLOAD_URL="https://ghfast.top/?q=raw.githubusercontent.com%2Fmeng-jin%2FAnyTLS%2Fmain%2Fmihomo.zip"
DEST_DIR="/usr/local/bin"
TEMP_ZIP="/tmp/mihomo.zip"

wget -O "$TEMP_ZIP" "$DOWNLOAD_URL"
unzip -o "$TEMP_ZIP" -d "$DEST_DIR"
chmod +x "$DEST_DIR"/*
rm -f "$TEMP_ZIP"

# 5. 创建配置目录
CONFIG_DIR="/etc/mihomo"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
mkdir -p "$CONFIG_DIR"

# 6. 生成自签证书
echo "正在生成自签证书..."
openssl ecparam -name prime256v1 -genkey -noout -out "$CONFIG_DIR/server.key"
openssl req -new -x509 -key "$CONFIG_DIR/server.key" -out "$CONFIG_DIR/server.crt" -days 36500 -subj "/CN=${CERT_CN}"

# 7. 写入 config.yaml
cat <<EOF > "$CONFIG_FILE"
mixed-port: 65222
tcp-concurrent: true
allow-lan: false
ipv6: true
log-level: info
rules:
  - MATCH,DIRECT
listeners:
  - name: anytls-in
    type: anytls
    port: ${ANYTLS_PORT}
    listen: "::"
    users:
      ${USER}: ${PASSWORD}
    certificate: ./server.crt
    private-key: ./server.key
EOF

chmod 644 "$CONFIG_FILE"
chown root:root "$CONFIG_FILE"

# 8. 创建 systemd 服务
SERVICE_FILE="/etc/systemd/system/mihomo.service"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=mihomo Daemon, Another Clash Kernel.
After=network.target NetworkManager.service systemd-networkd.service iwd.service

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
Restart=always
ExecStartPre=/usr/bin/sleep 1s
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"
chown root:root "$SERVICE_FILE"

# 9. 启动并启用服务
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable mihomo.service
systemctl start mihomo.service

# 获取 IP
IP=$(get_ip)

# 输出连接信息，高亮显示
echo -e "\n\033[36m\033[1m〓 NekoBox连接信息 〓\033[0m"
echo -e "\033[33m\033[1m请妥善保管此连接信息！\033[0m"
echo -e "\033[36manytls://${PASSWORD}@${IP}:${ANYTLS_PORT}/?insecure=1&sni=${CERT_CN}\033[0m"

echo -e "\nAnyTLS 安装完成！"
echo "- AnyTLS 端口: $ANYTLS_PORT"
echo "- 用户凭据: $USER_CREDENTIAL"
echo "- 证书域名: $CERT_CN"
