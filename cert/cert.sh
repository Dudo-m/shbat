#!/bin/bash

# 自签证书生成脚本 - 完全随机化版本
# 用法: ./generate_certs.sh

set -e

# ============ 随机字符串生成函数 ============
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'A-Za-z' | fold -w ${length} | head -n 1
}

generate_random_org_name() {
    local prefixes=("Global" "Tech" "Digital" "Secure" "Cloud" "Cyber" "Data" "Smart" "Quantum" "Innovation")
    local suffixes=("Corp" "Systems" "Solutions" "Technologies" "Services" "Labs" "Group" "Industries" "Dynamics" "Networks")

    local prefix=${prefixes[$RANDOM % ${#prefixes[@]}]}
    local suffix=${suffixes[$RANDOM % ${#suffixes[@]}]}
    local random_num=$((RANDOM % 9000 + 1000))

    echo "${prefix}${suffix}${random_num}"
}

generate_random_location() {
    local cities=("Seattle" "Austin" "Denver" "Portland" "Boston" "Phoenix" "Atlanta" "Chicago" "Dallas" "Miami" "NewYork" "SanFrancisco" "LosAngeles" "Houston")
    echo ${cities[$RANDOM % ${#cities[@]}]}
}

generate_random_state() {
    local states=("CA" "NY" "TX" "FL" "WA" "OR" "CO" "MA" "IL" "GA" "AZ" "NC" "VA" "PA")
    echo ${states[$RANDOM % ${#states[@]}]}
}

generate_random_country() {
    local countries=("US" "GB" "DE" "FR" "CA" "AU" "NL" "SE" "CH" "SG")
    echo ${countries[$RANDOM % ${#countries[@]}]}
}

generate_random_dept() {
    local depts=("Engineering" "Operations" "Security" "Infrastructure" "Development" "Technology" "Research" "Innovation" "Platform" "Cloud")
    echo ${depts[$RANDOM % ${#depts[@]}]}
}

# ============ 生成随机证书配置 ============
generate_random_cert_config() {
    echo ""
    echo "=========================================="
    echo "生成随机证书信息..."
    echo "=========================================="

    # CA 配置 - 随机有效期
    CA_DAYS=$((7000 + RANDOM % 730))  # 19-21年随机
    CA_COUNTRY=$(generate_random_country)
    CA_STATE=$(generate_random_state)
    CA_CITY=$(generate_random_location)
    CA_ORG=$(generate_random_org_name)
    CA_ORG_UNIT=$(generate_random_dept)
    # 随机化 CA Common Name 格式
    ca_formats=("${CA_ORG} Root CA" "${CA_ORG} CA" "${CA_ORG} Certificate Authority" "${CA_ORG} Root" "Root CA - ${CA_ORG}")
    CA_COMMON_NAME=${ca_formats[$RANDOM % ${#ca_formats[@]}]}

    # Server 证书配置 - 随机有效期
    SERVER_DAYS=$((3500 + RANDOM % 365))  # 9.5-10.5年随机
    SERVER_COUNTRY=$(generate_random_country)
    SERVER_STATE=$(generate_random_state)
    SERVER_CITY=$(generate_random_location)
    SERVER_ORG=$(generate_random_org_name)
    SERVER_ORG_UNIT=$(generate_random_dept)
    # 随机化域名格式
    random_len=$((6 + RANDOM % 6))  # 6-11个字符
    SERVER_COMMON_NAME="$(generate_random_string $random_len | tr '[:upper:]' '[:lower:]').local"

    # Client 证书配置 - 随机有效期
    CLIENT_DAYS=$((3500 + RANDOM % 365))  # 9.5-10.5年随机
    CLIENT_COUNTRY=$(generate_random_country)
    CLIENT_STATE=$(generate_random_state)
    CLIENT_CITY=$(generate_random_location)
    CLIENT_ORG=$(generate_random_org_name)
    CLIENT_ORG_UNIT=$(generate_random_dept)
    # 随机化 client 名称格式
    client_formats=("client-" "user-" "device-" "endpoint-" "node-")
    client_prefix=${client_formats[$RANDOM % ${#client_formats[@]}]}
    random_len=$((4 + RANDOM % 6))  # 4-9个字符
    CLIENT_COMMON_NAME="${client_prefix}$(generate_random_string $random_len | tr '[:upper:]' '[:lower:]')"

    echo "  CA 信息:"
    echo "    国家: $CA_COUNTRY"
    echo "    州/省: $CA_STATE"
    echo "    城市: $CA_CITY"
    echo "    组织: $CA_ORG"
    echo "    部门: $CA_ORG_UNIT"
    echo "    CN: $CA_COMMON_NAME"
    echo ""
    echo "  Server 信息:"
    echo "    国家: $SERVER_COUNTRY"
    echo "    州/省: $SERVER_STATE"
    echo "    城市: $SERVER_CITY"
    echo "    组织: $SERVER_ORG"
    echo "    部门: $SERVER_ORG_UNIT"
    echo "    CN: $SERVER_COMMON_NAME"
    echo ""
    echo "  Client 信息:"
    echo "    国家: $CLIENT_COUNTRY"
    echo "    州/省: $CLIENT_STATE"
    echo "    城市: $CLIENT_CITY"
    echo "    组织: $CLIENT_ORG"
    echo "    部门: $CLIENT_ORG_UNIT"
    echo "    CN: $CLIENT_COMMON_NAME"
    echo "=========================================="
}

# ============ 生成随机序列号函数 ============
generate_random_serial() {
    # 生成一个128位随机十六进制序列号
    openssl rand -hex 16
}

# ============ 清除证书函数 ============
delete_certs() {
    echo ""
    echo "=========================================="
    echo "清除证书文件..."
    echo "=========================================="

    CERT_FILES=(
        "ca.crt" "ca.key" "ca.srl"
        "server.crt" "server.key" "server.csr" "server.p12" "server.jks"
        "client.crt" "client.key" "client.csr" "client.p12" "client.jks"
        "truststore.jks" "cert_info.txt"
    )

    deleted=0
    for file in "${CERT_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo "  ✓ 已删除: $file"
            deleted=$((deleted + 1))
        fi
    done

    echo ""
    if [ $deleted -eq 0 ]; then
        echo "没有找到证书文件"
    else
        echo "清除完成: 删除 $deleted 个文件"
    fi
    echo "=========================================="
}

# ============ 生成证书函数 ============
generate_certs() {
    # 生成随机证书配置
    generate_random_cert_config

    echo ""
    echo "=========================================="
    echo "配置 SAN (Subject Alternative Name)"
    echo "=========================================="
    echo "请输入域名和IP地址 (多个用逗号分隔)"
    echo "格式示例: localhost,*.example.com,192.168.1.100,10.0.0.1"
    echo "直接回车使用默认: localhost,127.0.0.1"
    echo ""
    read -p "请输入: " san_input

    if [ -z "$san_input" ]; then
        SERVER_ALT_NAMES="DNS:localhost,IP:127.0.0.1"
        echo "使用默认 SAN: localhost, 127.0.0.1"
    else
        # 解析输入并构建 SAN
        SERVER_ALT_NAMES=""
        IFS=',' read -ra ITEMS <<< "$san_input"
        for item in "${ITEMS[@]}"; do
            item=$(echo "$item" | xargs)  # 去除空格
            if [[ $item =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                # IP地址
                if [ -z "$SERVER_ALT_NAMES" ]; then
                    SERVER_ALT_NAMES="IP:$item"
                else
                    SERVER_ALT_NAMES="$SERVER_ALT_NAMES,IP:$item"
                fi
            else
                # 域名
                if [ -z "$SERVER_ALT_NAMES" ]; then
                    SERVER_ALT_NAMES="DNS:$item"
                else
                    SERVER_ALT_NAMES="$SERVER_ALT_NAMES,DNS:$item"
                fi
            fi
        done
        echo "配置的 SAN: $SERVER_ALT_NAMES"
    fi

    echo ""
    read -s -p "请输入 P12/JKS 密码 (直接回车使用随机密码): " input_password
    echo ""
    if [ -z "$input_password" ]; then
        P12_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
        JKS_PASSWORD="$P12_PASSWORD"
        echo "使用随机密码: $P12_PASSWORD"
    else
        P12_PASSWORD="$input_password"
        JKS_PASSWORD="$input_password"
        echo "使用自定义密码"
    fi

    echo ""
    echo "=========================================="
    echo "开始生成证书..."
    echo "=========================================="

    # 1. 生成 CA 私钥和证书 (使用随机序列号和随机密钥长度)
    echo "1. 生成 CA 证书..."
    # 随机选择密钥长度: 2048, 3072, 4096
    ca_key_sizes=(2048 3072 4096)
    ca_key_size=${ca_key_sizes[$RANDOM % ${#ca_key_sizes[@]}]}
    echo "   CA 密钥长度: $ca_key_size bits"
    openssl genrsa -out ca.key $ca_key_size 2>/dev/null

    # 为 CA 生成随机序列号 (确保不是常见模式)
    CA_SERIAL=$(generate_random_serial)
    # 确保序列号不以00开头(避免常见模式)
    while [[ $CA_SERIAL == 00* ]]; do
        CA_SERIAL=$(generate_random_serial)
    done
    echo "   CA 序列号: $CA_SERIAL"

    openssl req -new -x509 -days ${CA_DAYS} -key ca.key -out ca.crt \
        -set_serial 0x${CA_SERIAL} \
        -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_CITY}/O=${CA_ORG}/OU=${CA_ORG_UNIT}/CN=${CA_COMMON_NAME}" 2>/dev/null

    echo "   ✓ CA 证书生成完成: ca.key, ca.crt"

    # 2. 生成 Server 私钥和 CSR (随机密钥长度)
    echo "2. 生成 Server 证书..."
    # 随机选择密钥长度: 2048, 3072
    server_key_sizes=(2048 3072)
    server_key_size=${server_key_sizes[$RANDOM % ${#server_key_sizes[@]}]}
    echo "   Server 密钥长度: $server_key_size bits"
    openssl genrsa -out server.key $server_key_size 2>/dev/null

    openssl req -new -key server.key -out server.csr \
        -subj "/C=${SERVER_COUNTRY}/ST=${SERVER_STATE}/L=${SERVER_CITY}/O=${SERVER_ORG}/OU=${SERVER_ORG_UNIT}/CN=${SERVER_COMMON_NAME}" 2>/dev/null

    # 创建 server 扩展配置文件
    cat > server_ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = ${SERVER_ALT_NAMES}
EOF

    # 生成随机序列号用于 Server 证书 (避免常见模式)
    SERVER_SERIAL=$(generate_random_serial)
    while [[ $SERVER_SERIAL == 00* ]] || [[ $SERVER_SERIAL == $CA_SERIAL ]]; do
        SERVER_SERIAL=$(generate_random_serial)
    done
    echo "   Server 序列号: $SERVER_SERIAL"

    # 使用 CA 签发 Server 证书 (使用随机序列号)
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
        -set_serial 0x${SERVER_SERIAL} \
        -out server.crt -days ${SERVER_DAYS} -sha256 -extfile server_ext.cnf 2>/dev/null

    rm -f server_ext.cnf

    echo "   ✓ Server 证书生成完成: server.key, server.csr, server.crt"

    # 3. 生成 Client 私钥和 CSR (随机密钥长度)
    echo "3. 生成 Client 证书..."
    # 随机选择密钥长度: 2048, 3072
    client_key_sizes=(2048 3072)
    client_key_size=${client_key_sizes[$RANDOM % ${#client_key_sizes[@]}]}
    echo "   Client 密钥长度: $client_key_size bits"
    openssl genrsa -out client.key $client_key_size 2>/dev/null

    openssl req -new -key client.key -out client.csr \
        -subj "/C=${CLIENT_COUNTRY}/ST=${CLIENT_STATE}/L=${CLIENT_CITY}/O=${CLIENT_ORG}/OU=${CLIENT_ORG_UNIT}/CN=${CLIENT_COMMON_NAME}" 2>/dev/null

    # 创建 client 扩展配置文件
    cat > client_ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = clientAuth
EOF

    # 生成随机序列号用于 Client 证书 (避免常见模式和重复)
    CLIENT_SERIAL=$(generate_random_serial)
    while [[ $CLIENT_SERIAL == 00* ]] || [[ $CLIENT_SERIAL == $CA_SERIAL ]] || [[ $CLIENT_SERIAL == $SERVER_SERIAL ]]; do
        CLIENT_SERIAL=$(generate_random_serial)
    done
    echo "   Client 序列号: $CLIENT_SERIAL"

    # 使用 CA 签发 Client 证书 (使用随机序列号)
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
        -set_serial 0x${CLIENT_SERIAL} \
        -out client.crt -days ${CLIENT_DAYS} -sha256 -extfile client_ext.cnf 2>/dev/null

    rm -f client_ext.cnf

    echo "   ✓ Client 证书生成完成: client.key, client.csr, client.crt"

    # 4. 生成 P12 格式证书
    echo "4. 生成 P12 格式证书..."
    # Server P12
    openssl pkcs12 -export -out server.p12 -inkey server.key -in server.crt -certfile ca.crt \
        -password pass:${P12_PASSWORD} -name "server" 2>/dev/null

    # Client P12
    openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt \
        -password pass:${P12_PASSWORD} -name "client" 2>/dev/null

    echo "   ✓ P12 证书生成完成: server.p12, client.p12"

    # 5. 可选:生成 JKS 格式证书
    jks_generated=0
    read -p "是否需要生成 JKS 格式证书? (y/n, 默认: n): " choice_jks
    if [[ "$choice_jks" =~ ^[Yy]$ ]]; then
        echo "5. 生成 JKS 格式证书..."
        # 检查 keytool 是否可用
        if ! command -v keytool &> /dev/null; then
            echo "   ⚠ 警告: 未找到 keytool 命令"
            echo ""
            echo "   安装 Java JDK 方法:"
            echo "   Ubuntu/Debian: sudo apt-get install openjdk-11-jdk"
            echo "   CentOS/RHEL:   sudo yum install java-11-openjdk-devel"
            echo "   Alpine:        apk add openjdk11"
            echo "   macOS:         brew install openjdk@11"
            echo ""
            echo "   或者直接使用已生成的 P12 文件,P12 格式在 Java 中同样被广泛支持"
            echo "   Java 代码示例: KeyStore.getInstance(\"PKCS12\")"
        else
            # 从 P12 转换为 JKS - Server
            keytool -importkeystore -srckeystore server.p12 -srcstoretype PKCS12 -srcstorepass ${P12_PASSWORD} \
                -destkeystore server.jks -deststoretype JKS -deststorepass ${JKS_PASSWORD} -noprompt 2>/dev/null

            # 从 P12 转换为 JKS - Client
            keytool -importkeystore -srckeystore client.p12 -srcstoretype PKCS12 -srcstorepass ${P12_PASSWORD} \
                -destkeystore client.jks -deststoretype JKS -deststorepass ${JKS_PASSWORD} -noprompt 2>/dev/null

            # 创建 Truststore (只包含 CA 证书)
            keytool -importcert -file ca.crt -keystore truststore.jks -storepass ${JKS_PASSWORD} \
                -alias ca -noprompt 2>/dev/null

            echo "   ✓ JKS 证书生成完成: server.jks, client.jks, truststore.jks"
            jks_generated=1
        fi
    fi

    # 6. 保存证书信息到文件
    cat > cert_info.txt <<EOF
========================================
证书信息记录
生成时间: $(date)
========================================

CA 证书信息:
  序列号: $CA_SERIAL
  国家: $CA_COUNTRY
  州/省: $CA_STATE
  城市: $CA_CITY
  组织: $CA_ORG
  部门: $CA_ORG_UNIT
  CN: $CA_COMMON_NAME
  有效期: $CA_DAYS 天

Server 证书信息:
  序列号: $SERVER_SERIAL
  国家: $SERVER_COUNTRY
  州/省: $SERVER_STATE
  城市: $SERVER_CITY
  组织: $SERVER_ORG
  部门: $SERVER_ORG_UNIT
  CN: $SERVER_COMMON_NAME
  SAN: $SERVER_ALT_NAMES
  有效期: $SERVER_DAYS 天

Client 证书信息:
  序列号: $CLIENT_SERIAL
  国家: $CLIENT_COUNTRY
  州/省: $CLIENT_STATE
  城市: $CLIENT_CITY
  组织: $CLIENT_ORG
  部门: $CLIENT_ORG_UNIT
  CN: $CLIENT_COMMON_NAME
  有效期: $CLIENT_DAYS 天

密码信息:
  P12/JKS 密码: $P12_PASSWORD

========================================
EOF

    # 7. 清理临时文件
    rm -f ca.srl

    echo ""
    echo "=========================================="
    echo "证书生成完成!"
    echo "=========================================="
    echo ""
    echo "生成的文件列表:"
    echo "  CA 证书:"
    echo "    - ca.crt (CA 根证书)"
    echo "    - ca.key (CA 私钥)"
    echo ""
    echo "  Server 证书:"
    echo "    - server.crt (Server 证书)"
    echo "    - server.key (Server 私钥)"
    echo "    - server.csr (Server 证书签名请求)"
    echo "    - server.p12 (Server PKCS#12 格式)"
    if [ $jks_generated -eq 1 ]; then
        echo "    - server.jks (Server Java KeyStore)"
    fi
    echo ""
    echo "  Client 证书:"
    echo "    - client.crt (Client 证书)"
    echo "    - client.key (Client 私钥)"
    echo "    - client.csr (Client 证书签名请求)"
    echo "    - client.p12 (Client PKCS#12 格式)"
    if [ $jks_generated -eq 1 ]; then
        echo "    - client.jks (Client Java KeyStore)"
        echo "    - truststore.jks (信任库)"
    fi
    echo ""
    echo "  其他文件:"
    echo "    - cert_info.txt (证书详细信息)"
    echo ""
    echo "P12/JKS 密码: $P12_PASSWORD"
    echo ""
    echo "⚠ 提示: 证书信息已保存到 cert_info.txt"
    echo "⚠ 提示: 这些是自签证书,仅用于开发和测试环境!"
    echo "=========================================="
    echo ""
    echo "验证证书序列号:"
    echo "  CA:     openssl x509 -in ca.crt -noout -serial"
    echo "  Server: openssl x509 -in server.crt -noout -serial"
    echo "  Client: openssl x509 -in client.crt -noout -serial"
    echo ""
    echo "查看证书详细信息:"
    echo "  openssl x509 -in server.crt -noout -text"
    echo "=========================================="
}

# ============ 主菜单 ============
show_menu() {
    clear
    echo "=========================================="
    echo "   自签证书生成工具 (完全随机化版)"
    echo "=========================================="
    echo "1. 生成证书 (随机序列号 + 随机信息)"
    echo "2. 清除证书"
    echo "3. 退出"
    echo "=========================================="
    echo "特性:"
    echo "  ✓ 随机序列号 (避免 Fofa 指纹识别)"
    echo "  ✓ 随机组织/国家/城市信息"
    echo "  ✓ 随机 CN 名称"
    echo "  ✓ 可选随机密码"
    echo "=========================================="
    echo -n "请选择操作 [1-3]: "
}

# ============ 主程序 ============
while true; do
    show_menu
    read choice

    case $choice in
        1)
            generate_certs
            echo ""
            read -p "按回车键继续..."
            ;;
        2)
            delete_certs
            echo ""
            read -p "按回车键继续..."
            ;;
        3)
            echo "退出程序"
            exit 0
            ;;
        *)
            echo "无效选择,请重新输入"
            sleep 1
            ;;
    esac
done