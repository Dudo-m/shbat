#!/bin/bash

# 自签证书生成脚本
# 用法: ./generate_certs.sh

set -e

# ============ 配置参数 ============
# CA 配置
CA_DAYS=3650
CA_COUNTRY="US"
CA_STATE="Anonymous"
CA_CITY="Local CA"
CA_ORG="MyCompany"
CA_ORG_UNIT="IT Department"
CA_COMMON_NAME="MyCompany Root CA"

# Server 证书配置
SERVER_DAYS=365
SERVER_COUNTRY="US"
SERVER_STATE="Internal"
SERVER_CITY="Dev Server"
SERVER_ORG="MyCompany"
SERVER_ORG_UNIT="IT Department"
SERVER_COMMON_NAME="localhost"

# Client 证书配置
CLIENT_DAYS=365
CLIENT_COUNTRY="US"
CLIENT_STATE="Internal"
CLIENT_CITY="Client Unit"
CLIENT_ORG="MyCompany"
CLIENT_ORG_UNIT="IT Department"
CLIENT_COMMON_NAME="client"

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
        "truststore.jks"
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
    read -s -p "请输入 P12/JKS 密码 (直接回车使用默认密码 'changeit'): " input_password
    echo ""
    if [ -z "$input_password" ]; then
        P12_PASSWORD="changeit"
        JKS_PASSWORD="changeit"
        echo "使用默认密码: changeit"
    else
        P12_PASSWORD="$input_password"
        JKS_PASSWORD="$input_password"
        echo "使用自定义密码"
    fi

    echo ""
    echo "=========================================="
    echo "开始生成证书..."
    echo "=========================================="

    # 1. 生成 CA 私钥和证书
    echo "1. 生成 CA 证书..."
    openssl genrsa -out ca.key 4096 2>/dev/null

    openssl req -new -x509 -days ${CA_DAYS} -key ca.key -out ca.crt \
        -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_CITY}/O=${CA_ORG}/OU=${CA_ORG_UNIT}/CN=${CA_COMMON_NAME}" 2>/dev/null

    echo "   ✓ CA 证书生成完成: ca.key, ca.crt"

    # 2. 生成 Server 私钥和 CSR
    echo "2. 生成 Server 证书..."
    openssl genrsa -out server.key 2048 2>/dev/null

    openssl req -new -key server.key -out server.csr \
        -subj "/C=${SERVER_COUNTRY}/ST=${SERVER_STATE}/L=${SERVER_CITY}/O=${SERVER_ORG}/OU=${SERVER_ORG_UNIT}/CN=${SERVER_COMMON_NAME}" 2>/dev/null

    # 创建 server 扩展配置文件
    cat > server_ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = ${SERVER_ALT_NAMES}
EOF

    # 使用 CA 签发 Server 证书
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
        -out server.crt -days ${SERVER_DAYS} -sha256 -extfile server_ext.cnf 2>/dev/null

    rm -f server_ext.cnf

    echo "   ✓ Server 证书生成完成: server.key, server.csr, server.crt"

    # 3. 生成 Client 私钥和 CSR
    echo "3. 生成 Client 证书..."
    openssl genrsa -out client.key 2048 2>/dev/null

    openssl req -new -key client.key -out client.csr \
        -subj "/C=${CLIENT_COUNTRY}/ST=${CLIENT_STATE}/L=${CLIENT_CITY}/O=${CLIENT_ORG}/OU=${CLIENT_ORG_UNIT}/CN=${CLIENT_COMMON_NAME}" 2>/dev/null

    # 创建 client 扩展配置文件
    cat > client_ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = clientAuth
EOF

    # 使用 CA 签发 Client 证书
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
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

    # 5. 生成 JKS 格式证书
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
        echo "   或者直接使用已生成的 P12 文件，P12 格式在 Java 中同样被广泛支持"
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
    fi

    # 6. 清理临时文件
    rm -f ca.srl

    echo ""
    echo "=========================================="
    echo "证书生成完成！"
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
    if command -v keytool &> /dev/null; then
        echo "    - server.jks (Server Java KeyStore)"
    fi
    echo ""
    echo "  Client 证书:"
    echo "    - client.crt (Client 证书)"
    echo "    - client.key (Client 私钥)"
    echo "    - client.csr (Client 证书签名请求)"
    echo "    - client.p12 (Client PKCS#12 格式)"
    if command -v keytool &> /dev/null; then
        echo "    - client.jks (Client Java KeyStore)"
        echo "    - truststore.jks (信任库)"
    fi
    echo ""
    echo "P12/JKS 密码: ${P12_PASSWORD}"
    echo ""
    echo "⚠ 提示: 这些是自签证书，仅用于开发和测试环境！"
    echo "=========================================="
}

# ============ 主菜单 ============
show_menu() {
    clear
    echo "=========================================="
    echo "      自签证书生成工具"
    echo "=========================================="
    echo "1. 生成证书"
    echo "2. 清除证书"
    echo "3. 退出"
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
            echo "无效选择，请重新输入"
            sleep 1
            ;;
    esac
done