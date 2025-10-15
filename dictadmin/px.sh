#!/bin/bash

#彩色输出
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 脚本变量
WORKING_DIR="px"
EXECUTABLE_NAME="x"
CONFIG_FILE="xr.json"
LOG_FILE="log"
XRAY_VERSION="v25.9.11" # 您可以根据需要更改为最新的版本
UUID="70695e54-844f-4486-a0b6-edf2ca3bbb0f" # 使用您提供的UUID

# 步骤 1: 检查依赖
check_dependencies() {
    green "===== 步骤 1: 正在检查系统依赖... ====="
    command -v curl >/dev/null 2>&1 || { red "错误: curl 未安装。请先安装 curl。"; exit 1; }
    command -v wget >/dev/null 2>&1 || { red "错误: wget 未安装。请先安装 wget。"; exit 1; }
    command -v unzip >/dev/null 2>&1 || { red "错误: unzip 未安装。请先安装 unzip。"; exit 1; }
    green "依赖检查通过！"
    echo
}

# 步骤 2: 获取用户输入和系统信息
get_user_and_system_info() {
    green "===== 步骤 2: 正在收集配置信息... ====="
    # 交互式输入端口
    read -p "请输入代理要监听的端口 (默认: 35100): " PORT
    PORT=${PORT:-35100} # 如果用户未输入，则使用默认值

    # 自动检测公网IP
    yellow "正在自动检测公网IP地址..."
    IP=$(curl -s4 ip.sb) || IP=$(curl -s4 ifconfig.me)
    if [ -z "$IP" ]; then
        red "错误: 无法自动检测到公网IP地址。"
        read -p "请手动输入您的公网IP地址: " IP
        if [ -z "$IP" ]; then
            red "错误: 未提供IP地址，脚本终止。"
            exit 1
        fi
    fi
    green "端口: $PORT"
    green "公网IP: $IP"
    echo
}

# 步骤 3: 下载并准备 Xray
setup_xray() {
    green "===== 步骤 3: 正在下载并配置 Xray... ====="
    # 创建工作目录
    mkdir -p $WORKING_DIR
    cd $WORKING_DIR

    # 下载并解压Xray
    yellow "正在下载 Xray-core..."
    wget -O Xray-linux-64.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"
    if [ $? -ne 0 ]; then
        red "Xray 下载失败，请检查网络或版本号 ${XRAY_VERSION} 是否正确。"
        exit 1
    fi

    unzip -o Xray-linux-64.zip
    rm Xray-linux-64.zip

    # 重命名可执行文件以避免被检测
    mv xray $EXECUTABLE_NAME
    chmod +x $EXECUTABLE_NAME
    green "Xray 已成功下载并重命名为 '$EXECUTABLE_NAME'。"
    echo
}

# 步骤 4: 生成密钥对和配置文件
generate_config() {
    green "===== 步骤 4: 正在生成密钥对和配置文件... ====="
    yellow "正在生成新的 REALITY 密钥对..."
    KEY_PAIR=$(./$EXECUTABLE_NAME x25519)
    PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "PrivateKey" | awk -F': ' '{print $2}')
    PASSWORD=$(echo "$KEY_PAIR" | grep "Password" | awk -F': ' '{print $2}')
    HASH32=$(echo "$KEY_PAIR" | grep "Hash32" | awk -F': ' '{print $2}')

    if [ -z "$PRIVATE_KEY" ]; then
        red "错误: 生成密钥对失败！"
        exit 1
    fi

    green "私钥: $PRIVATE_KEY"
    green "公钥: $PASSWORD"

    yellow "正在生成配置文件 '$CONFIG_FILE'..."

    # 使用cat和EOF来创建配置文件，并动态替换变量
    cat > $CONFIG_FILE <<EOF
{
  "log": {
    "loglevel": "none"
  },
  "dns": {
    "servers": [
      "8.8.8.8"
    ]
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "chrome",
          "dest": "apple.com:443",
          "serverNames": [
            "apple.com"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "a7903144"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
    green "配置文件生成完毕。"
    echo
}

# 步骤 5: 启动服务
start_service() {
    green "===== 步骤 5: 正在启动服务... ====="

    # 如果已有进程在运行，先杀掉它
    if pgrep -f "./${EXECUTABLE_NAME} run -config ${CONFIG_FILE}"; then
        yellow "检测到已有服务在运行，正在尝试停止..."
        pkill -f "./${EXECUTABLE_NAME} run -config ${CONFIG_FILE}"
        sleep 2
    fi

    # 检查系统是否有nohup命令
    if command -v nohup >/dev/null 2>&1; then
        yellow "使用 nohup 启动服务..."
        nohup ./$EXECUTABLE_NAME run -config $CONFIG_FILE &> $LOG_FILE &
    else
        yellow "nohup 不可用，使用 disown 启动服务..."
        # 以后台模式启动，并将所有输出重定向到日志文件
        ./$EXECUTABLE_NAME run -config $CONFIG_FILE &> $LOG_FILE &
        # 分离进程，使其在关闭终端后继续运行
        disown -h %1
    fi

    sleep 2 # 等待2秒确保服务已启动

    # 检查进程是否成功启动
    if pgrep -f "./${EXECUTABLE_NAME} run -config ${CONFIG_FILE}"; then
        green "服务已成功启动！"
    else
        red "错误: 服务启动失败！请检查日志文件 '${WORKING_DIR}/${LOG_FILE}' 获取详细信息。"
        exit 1
    fi
    echo
}

# 步骤 6: 显示结果
display_results() {
    green "===== 部署完成！以下是您的节点信息 ====="
    NODE_LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=apple.com&fp=chrome&pbk=${PASSWORD}&sid=a7903144&type=tcp&headerType=none#REALITY-$(hostname)"

    yellow "--------------------------------------------------"
    echo " "
    green "VLESS REALITY 节点链接:"
    red "${NODE_LINK}"
    echo " "
    yellow "--------------------------------------------------"
    echo " "
    green "管理命令:"
    echo "查看日志: cd ${WORKING_DIR} && cat ${LOG_FILE}"
    echo "停止服务: pkill -f ./${EXECUTABLE_NAME}"
    echo "启动服务: cd ${WORKING_DIR} && ./${EXECUTABLE_NAME} run -config ${CONFIG_FILE} &> ${LOG_FILE} & disown -h"
    echo " "
}

# 主函数
main() {
    check_dependencies
    get_user_and_system_info
    setup_xray
    generate_config
    start_service
    display_results
}

# 运行主函数
main