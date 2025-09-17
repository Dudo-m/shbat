#!/bin/bash

# Ubuntu VPN 服务安装脚本
# 支持: PPTP, L2TP/IPsec, OpenVPN

set -euo pipefail

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "请以root用户运行此脚本。"
   exit 1
fi

# 检查系统类型
if ! grep -Eqi "ubuntu|debian" /etc/os-release; then
    echo "此脚本仅支持 Ubuntu/Debian 系统。"
    exit 1
fi

# 获取主网络接口
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
if [ -z "$MAIN_INTERFACE" ]; then
    MAIN_INTERFACE="eth0"
fi
echo "检测到的主网络接口: $MAIN_INTERFACE"

# 安装依赖
install_dependencies() {
    echo "正在安装依赖..."
    apt update
    apt install -y psmisc net-tools curl ufw iptables-persistent
    ufw --force enable
    echo "依赖安装完成。"
}

# 配置防火墙
configure_firewall() {
    local service_type=$1
    local action=${2:-add}
    
    echo "正在配置防火墙 ($action) 用于 $service_type..."
    
    if [ "$action" == "add" ]; then
        ufw allow OpenSSH
        case "$service_type" in
            "pptp")
                ufw allow 1723/tcp
                # 配置NAT规则
                if ! grep -q "*nat" /etc/ufw/before.rules; then
                    cat >> /etc/ufw/before.rules << EOF

*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 192.168.0.0/24 -o $MAIN_INTERFACE -j MASQUERADE
COMMIT
EOF
                fi
                sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
                ;;
            "l2tp")
                ufw allow 500/udp
                ufw allow 4500/udp
                ufw allow 1701/udp
                ;;
            "openvpn")
                ufw allow 1194/udp
                cp /etc/default/ufw /etc/default/ufw.bak 2>/dev/null || true
                cp /etc/ufw/before.rules /etc/ufw/before.rules.bak 2>/dev/null || true
                sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
                if ! grep -q "*nat" /etc/ufw/before.rules; then
                    cat >> /etc/ufw/before.rules << EOF

*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/24 -o $MAIN_INTERFACE -j MASQUERADE
COMMIT
EOF
                fi
                ;;
        esac
        ufw disable && ufw --force enable
    else
        case "$service_type" in
            "pptp")
                ufw delete allow 1723/tcp
                ;;
            "l2tp")
                ufw delete allow 500/udp
                ufw delete allow 4500/udp
                ufw delete allow 1701/udp
                ;;
            "openvpn")
                ufw delete allow 1194/udp
                if [ -f "/etc/default/ufw.bak" ]; then
                    mv /etc/default/ufw.bak /etc/default/ufw
                fi
                if [ -f "/etc/ufw/before.rules.bak" ]; then
                    mv /etc/ufw/before.rules.bak /etc/ufw/before.rules
                fi
                ;;
        esac
        ufw disable && ufw --force enable
    fi
}

# PPTP 安装
install_pptp() {
    echo "正在安装 PPTP VPN 服务..."
    apt install -y pptpd ppp
    systemctl enable pptpd

    cat > /etc/pptpd.conf << EOF
option /etc/ppp/pptpd-options
logwtmp
localip 192.168.0.1
remoteip 192.168.0.100-200
EOF

    cat > /etc/ppp/pptpd-options << EOF
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
ms-dns 8.8.8.8
ms-dns 8.8.4.4
EOF

    read -p "请输入PPTP用户名: " pptp_user
    read -p "请输入PPTP密码: " pptp_password
    echo "$pptp_user pptpd $pptp_password *" >> /etc/ppp/chap-secrets

    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

    configure_firewall "pptp"
    systemctl restart pptpd

    echo "PPTP VPN 服务安装完成！"
    echo "用户名: $pptp_user"
    echo "密码: $pptp_password"
    echo "服务器地址: $(curl -s ipinfo.io/ip)"
}

# L2TP/IPsec 安装
install_l2tp() {
    echo "正在安装 L2TP/IPsec VPN 服务..."
    
    read -p "请输入IP地址池前缀 (默认: 192.168.18): " iprange
    iprange=${iprange:-192.168.18}

    read -p "请输入预共享密钥PSK (默认: 随机生成): " mypsk
    if [ -z "$mypsk" ]; then
        mypsk=$(openssl rand -base64 16)
    fi

    read -p "请输入L2TP用户名 (默认: l2tpuser): " l2tp_user
    l2tp_user=${l2tp_user:-l2tpuser}

    read -p "请输入L2TP密码 (默认: 随机生成): " l2tp_password
    if [ -z "$l2tp_password" ]; then
        l2tp_password=$(openssl rand -base64 12)
    fi

    apt update
    apt install -y libreswan xl2tpd
    systemctl enable ipsec xl2tpd

    # 配置IPsec
    cat > /etc/ipsec.conf << EOF
version 2.0

config setup
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v6:fd00::/8,%v6:fe80::/10
    protostack=netkey
    interfaces=%defaultroute
    uniqueids=no

conn shared
    left=%defaultroute
    leftid=%myid
    right=%any
    encapsulation=yes
    authby=secret
    pfs=no
    rekey=no
    keyingtries=5
    dpddelay=30
    dpdtimeout=120
    dpdaction=clear
    ike=3des-sha1,aes128-sha1,aes256-sha1,aes128-sha2,aes256-sha2
    phase2alg=3des-sha1,aes128-sha1,aes256-sha1,aes128-sha2,aes256-sha2

conn l2tp-psk
    auto=add
    leftprotoport=17/1701
    rightprotoport=17/%any
    type=transport
    phase2=esp
    also=shared
EOF

    cat > /etc/ipsec.secrets << EOF
%any %any : PSK "${mypsk}"
EOF
    chmod 600 /etc/ipsec.secrets

    # 配置xl2tpd
    cat > /etc/xl2tpd/xl2tpd.conf << EOF
[global]
listen-addr = 0.0.0.0

[lns default]
ip range = ${iprange}.2-${iprange}.254
local ip = ${iprange}.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

    cat > /etc/ppp/options.xl2tpd << EOF
+mschap-v2
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
hide-password
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
proxyarp
connect-delay 5000
EOF

    echo "${l2tp_user} l2tpd ${l2tp_password} *" >> /etc/ppp/chap-secrets

    # 配置系统网络设置
    cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.lo.rp_filter = 0
net.ipv4.conf.${MAIN_INTERFACE}.rp_filter = 0
EOF

    sysctl -p

    configure_firewall "l2tp"
    systemctl restart ipsec xl2tpd

    echo "L2TP/IPsec VPN 服务安装完成！"
    echo "服务器IP: $(curl -s ipinfo.io/ip)"
    echo "预共享密钥(PSK): ${mypsk}"
    echo "用户名: ${l2tp_user}"
    echo "密码: ${l2tp_password}"
}

# OpenVPN 安装
install_openvpn() {
    echo "正在安装 OpenVPN 服务..."
    apt install -y openvpn easy-rsa
    
    mkdir -p /etc/openvpn/easy-rsa/keys
    cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
    cd /etc/openvpn/easy-rsa/

    ./easyrsa init-pki
    echo "" | ./easyrsa build-ca nopass
    echo "" | ./easyrsa gen-req server nopass
    echo "yes" | ./easyrsa sign-req server server
    ./easyrsa gen-dh
    openvpn --genkey --secret ta.key

    cp pki/ca.crt pki/issued/server.crt pki/private/server.key ta.key pki/dh.pem /etc/openvpn/

    cat > /etc/openvpn/server.conf << EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

    systemctl enable openvpn@server
    systemctl start openvpn@server

    configure_firewall "openvpn"

    echo "OpenVPN 服务安装完成！"
    generate_openvpn_client
}

# 生成OpenVPN客户端配置
generate_openvpn_client() {
    cd /etc/openvpn/easy-rsa/
    
    read -p "请输入客户端名称 (例如: client1): " client_name
    client_name=${client_name:-client1}

    if [ ! -f "pki/issued/${client_name}.crt" ]; then
        echo "" | ./easyrsa gen-req "$client_name" nopass
        echo "yes" | ./easyrsa sign-req client "$client_name"
    fi

    server_ip=$(curl -s ifconfig.me)

    cat > /root/"$client_name".ovpn << EOF
client
dev tun
proto udp
remote $server_ip 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
comp-lzo
verb 3
key-direction 1
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
<cert>
$(cat pki/issued/"$client_name".crt)
</cert>
<key>
$(cat pki/private/"$client_name".key)
</key>
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF
    echo "客户端配置文件已生成到 /root/$client_name.ovpn"
}

# 卸载函数
uninstall_pptp() {
    systemctl stop pptpd
    systemctl disable pptpd
    apt remove -y pptpd
    rm -f /etc/pptpd.conf /etc/ppp/pptpd-options
    sed -i "/ pptpd /d" /etc/ppp/chap-secrets
    configure_firewall "pptp" "remove"
    echo "PPTP VPN 服务已卸载。"
}

uninstall_l2tp() {
    systemctl stop xl2tpd ipsec
    systemctl disable xl2tpd ipsec
    apt remove -y libreswan xl2tpd
    rm -f /etc/ipsec.conf /etc/ipsec.secrets /etc/xl2tpd/xl2tpd.conf /etc/ppp/options.xl2tpd
    sed -i "/ l2tpd /d" /etc/ppp/chap-secrets
    configure_firewall "l2tp" "remove"
    echo "L2TP/IPsec VPN 服务已卸载。"
}

uninstall_openvpn() {
    systemctl stop openvpn@server
    systemctl disable openvpn@server
    apt remove -y openvpn easy-rsa
    rm -rf /etc/openvpn/*
    configure_firewall "openvpn" "remove"
    echo "OpenVPN 服务已卸载。"
}

# 主菜单
main_menu() {
    install_dependencies

    clear
    echo "----------------------------------------"
    echo "       Ubuntu VPN 服务管理脚本"
    echo "----------------------------------------"
    echo "1. 安装 PPTP VPN"
    echo "2. 卸载 PPTP VPN"
    echo "3. 安装 L2TP/IPsec VPN"
    echo "4. 卸载 L2TP/IPsec VPN"
    echo "5. 安装 OpenVPN"
    echo "6. 卸载 OpenVPN"
    echo "7. 生成 OpenVPN 客户端配置"
    echo "0. 退出"
    echo "----------------------------------------"

    read -p "请选择一个选项: " option

    case $option in
        1) install_pptp ;;
        2) uninstall_pptp ;;
        3) install_l2tp ;;
        4) uninstall_l2tp ;;
        5) install_openvpn ;;
        6) uninstall_openvpn ;;
        7) generate_openvpn_client ;;
        0) echo "脚本已退出。"; exit 0 ;;
        *) echo "无效的选项，请重新选择。"; sleep 2; main_menu ;;
    esac

    read -p "按任意键返回主菜单..."
    main_menu
}

# 运行主菜单
main_menu