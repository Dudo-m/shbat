#!/bin/bash

# 彩色输出函数
red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }

# 脚本变量
WORK_DIR="sb"
EXEC_NAME="s"
CONFIG_FILE="cfg.json"
LOG_FILE="run.log"
SINGBOX_VERSION="1.9.7"
UUID="70695e54-844f-4486-a0b6-edf2ca3bbb0f"

# 步骤 1: 检查依赖
check_deps() {
    green "===== 步骤 1: 检查系统依赖... ====="
    command -v curl >/dev/null 2>&1 || { red "错误: curl 未安装"; exit 1; }
    command -v wget >/dev/null 2>&1 || { red "错误: wget 未安装"; exit 1; }
    command -v tar >/dev/null 2>&1 || { red "错误: tar 未安装"; exit 1; }
    green "依赖检查通过"
    echo
}

# 步骤 2: 获取用户输入
get_user_info() {
    green "===== 步骤 2: 收集配置信息... ====="

    # 选择协议
    echo "请选择代理协议:"
    echo "1) TUIC v5"
    echo "2) Hysteria2"
    read -p "请输入选项 (1/2, 默认: 1): " PROTO_CHOICE
    PROTO_CHOICE=${PROTO_CHOICE:-1}

    if [ "$PROTO_CHOICE" == "2" ]; then
        PROTOCOL="hysteria2"
        DEFAULT_PORT=36100
    else
        PROTOCOL="tuic"
        DEFAULT_PORT=35200
    fi

    # 输入端口
    read -p "请输入监听端口 (默认: ${DEFAULT_PORT}): " PORT
    PORT=${PORT:-$DEFAULT_PORT}

    # 输入密码
    read -p "请输入连接密码 (默认: 随机生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        # 使用更简单的方法生成随机密码，避免fork失败
        PASSWORD=$(date +%s%N | md5sum 2>/dev/null | cut -c1-16 || echo "$(date +%s)${RANDOM}" | md5sum 2>/dev/null | cut -c1-16 || echo "Pass$(date +%s)")
    fi

    # 检测公网IP
    yellow "正在检测公网IP..."
    IP=$(curl -s4 --max-time 5 ip.sb 2>/dev/null || curl -s4 --max-time 5 ifconfig.me 2>/dev/null || curl -s4 --max-time 5 icanhazip.com 2>/dev/null)

    if [ -z "$IP" ]; then
        red "无法自动检测IP"
        read -p "请手动输入公网IP: " IP
        [ -z "$IP" ] && { red "未提供IP，退出"; exit 1; }
    fi

    green "协议: $([ "$PROTOCOL" == "tuic" ] && echo "TUIC v5" || echo "Hysteria2")"
    green "端口: $PORT"
    green "密码: $PASSWORD"
    green "公网IP: $IP"
    echo
}

# 步骤 3: 下载 sing-box
setup_singbox() {
    green "===== 步骤 3: 下载并配置 sing-box... ====="
    mkdir -p $WORK_DIR
    cd $WORK_DIR

    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_NAME="amd64" ;;
        aarch64) ARCH_NAME="arm64" ;;
        armv7l) ARCH_NAME="armv7" ;;
        *) red "不支持的架构: $ARCH"; exit 1 ;;
    esac

    yellow "正在下载 sing-box ${SINGBOX_VERSION} (${ARCH_NAME})..."
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-${ARCH_NAME}.tar.gz"

    wget -q --show-progress -O sb.tar.gz "$DOWNLOAD_URL" || {
        red "下载失败，请检查网络或版本号"
        exit 1
    }

    tar -xzf sb.tar.gz
    mv sing-box-${SINGBOX_VERSION}-linux-${ARCH_NAME}/sing-box $EXEC_NAME 2>/dev/null || \
    find . -name "sing-box" -type f -exec mv {} $EXEC_NAME \;

    rm -rf sb.tar.gz sing-box-${SINGBOX_VERSION}-linux-*
    chmod +x $EXEC_NAME

    green "sing-box 已下载并重命名为 '$EXEC_NAME'"
    echo
}

# 步骤 4: 生成自签证书和配置
generate_config() {
    green "===== 步骤 4: 生成证书和配置文件... ====="

    # 使用 sing-box 自带的证书生成功能
    yellow "正在生成自签证书..."
    ./$EXEC_NAME generate tls-keypair -o . 2>/dev/null || {
        # 如果失败，使用内嵌的纯文本证书
        yellow "使用备用证书方案..."
        cat > cert.pem <<'CERTEOF'
-----BEGIN CERTIFICATE-----
MIIBhTCCASugAwIBAgIUOZQHrwkDIovEQhgxdSYuvSytA7cwCgYIKoZIzj0EAwIw
FzEVMBMGA1UEAwwMd3d3LmJpbmcuY29tMCAXDTI1MTAxMTA4MTExNVoYDzIxMjUw
OTE3MDgxMTE1WjAXMRUwEwYDVQQDDAx3d3cuYmluZy5jb20wWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAATslcu/BY7rUCb45qLPbaC1U8bQeyvUYtR2X4N5q9CixgHa
v+p5m8aHmkmfMCnBVRHJJ5Iw/ofEto5KRtCARHrTo1MwUTAdBgNVHQ4EFgQUU8gg
u2NYyliM9c5CDcJFks/Bnn0wHwYDVR0jBBgwFoAUU8ggu2NYyliM9c5CDcJFks/B
nn0wDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiBvG3UwVMf/YYQ9
DAO5tu2SxZkVDHo0bLQ6bx8iGzC2xQIhAIMocegHLgdV5I9csASz6fal2BmKkr0J
1YmzTKjPk2ck
-----END CERTIFICATE-----
CERTEOF

        cat > key.pem <<'KEYEOF'
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIJUFgyQ5ntrI39aI7BqR4GLI5jCKokqbe5XL/G2U9gH+oAoGCCqGSM49
AwEHoUQDQgAE7JXLvwWO61Am+Oaiz22gtVPG0Hsr1GLUdl+DeavQosYB2r/qeZvG
h5pJnzApwVURySeSMP6HxLaOSkbQgER60w==
-----END EC PRIVATE KEY-----
KEYEOF
    }

    green "证书文件已创建"

    if [ "$PROTOCOL" == "tuic" ]; then
        generate_tuic_config
    else
        generate_hy2_config
    fi

    green "配置文件生成完毕"
    echo
}

# 生成 TUIC 配置
generate_tuic_config() {
    cat > $CONFIG_FILE <<EOF
{
  "log": {
    "level": "error",
    "timestamp": false
  },
  "inbounds": [
    {
      "type": "tuic",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "uuid": "${UUID}",
          "password": "${PASSWORD}"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "cert.pem",
        "key_path": "key.pem"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF
}

# 生成 Hysteria2 配置
generate_hy2_config() {
    cat > $CONFIG_FILE <<EOF
{
  "log": {
    "level": "error",
    "timestamp": false
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "password": "${PASSWORD}"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "cert.pem",
        "key_path": "key.pem"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF
}

# 步骤 5: 启动服务
start_service() {
    green "===== 步骤 5: 启动服务... ====="

    # 停止已有进程
    pkill -f "./${EXEC_NAME}" 2>/dev/null
    sleep 1

    # 启动服务（兼容无 nohup 环境）
    if command -v nohup >/dev/null 2>&1; then
        nohup ./$EXEC_NAME run -c $CONFIG_FILE >$LOG_FILE 2>&1 &
    else
        ./$EXEC_NAME run -c $CONFIG_FILE >$LOG_FILE 2>&1 &
        disown 2>/dev/null || true
    fi

    sleep 2

    # 验证启动
    if pgrep -f "./${EXEC_NAME}" >/dev/null; then
        green "服务启动成功"
    else
        red "服务启动失败，查看日志: cat ${WORK_DIR}/${LOG_FILE}"
        exit 1
    fi
    echo
}

# 步骤 6: 显示节点信息
display_results() {
    green "===== 部署完成！节点信息 ====="

    if [ "$PROTOCOL" == "tuic" ]; then
        NODE_LINK="tuic://${UUID}:${PASSWORD}@${IP}:${PORT}?congestion_control=bbr&alpn=h3&allow_insecure=1#TUIC-$(hostname)"
        echo
        yellow "TUIC v5 节点链接:"
        red "${NODE_LINK}"
        echo
        yellow "客户端配置参数:"
        echo "服务器: ${IP}"
        echo "端口: ${PORT}"
        echo "UUID: ${UUID}"
        echo "密码: ${PASSWORD}"
        echo "拥塞控制: bbr"
        echo "ALPN: h3"
    else
        NODE_LINK="hysteria2://${PASSWORD}@${IP}:${PORT}?insecure=1&sni=bing.com#HY2-$(hostname)"
        echo
        yellow "Hysteria2 节点链接:"
        red "${NODE_LINK}"
        echo
        yellow "客户端配置参数:"
        echo "服务器: ${IP}"
        echo "端口: ${PORT}"
        echo "密码: ${PASSWORD}"
        echo "SNI: bing.com"
    fi

    echo
    yellow "--------------------------------------------------"
    green "管理命令:"
    echo "查看日志: cd ${WORK_DIR} && tail -f ${LOG_FILE}"
    echo "停止服务: pkill -f ${EXEC_NAME}"
    echo "重启服务: cd ${WORK_DIR} && ./${EXEC_NAME} run -c ${CONFIG_FILE} >${LOG_FILE} 2>&1 &"
    echo
}

# 主函数
main() {
    check_deps
    get_user_info
    setup_singbox
    generate_config
    start_service
    display_results
}

main