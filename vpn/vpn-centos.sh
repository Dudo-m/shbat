#!/bin/bash

# CentOS VPN 服务安装脚本
# 支持: PPTP, L2TP/IPsec, OpenVPN

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "请以root用户运行此脚本。"
   exit 1
fi

# 检查系统类型
if ! grep -Eqi "centos|rhel|fedora" /etc/os-release; then
    echo "此脚本仅支持 CentOS/RHEL/Fedora 系统。"
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
    yum install -y epel-release
    yum install -y psmisc net-tools curl iptables-services firewalld
    systemctl enable firewalld
    systemctl start firewalld
    echo "依赖安装完成。"
}

# 配置防火墙
configure_firewall() {
    local service_type=$1
    local action=${2:-add}

    echo "正在配置防火墙 ($action) 用于 $service_type..."

    if [ "$action" == "add" ]; then
        firewall-cmd --zone=public --add-masquerade --permanent
        case "$service_type" in
            "pptp")
                firewall-cmd --permanent --add-port=1723/tcp
                firewall-cmd --permanent --add-protocol=gre
                firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i ppp+ -j ACCEPT
                firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -o ppp+ -j ACCEPT
                firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 192.168.0.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE
                ;;
            "l2tp")
                firewall-cmd --permanent --add-port=500/udp
                firewall-cmd --permanent --add-port=4500/udp
                firewall-cmd --permanent --add-port=1701/udp
                ;;
            "openvpn")
                firewall-cmd --permanent --add-port=1194/udp
                firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE
                firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i tun+ -o "$MAIN_INTERFACE" -j ACCEPT
                firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$MAIN_INTERFACE" -o tun+ -j ACCEPT
                ;;
        esac
    else
        case "$service_type" in
            "pptp")
                firewall-cmd --permanent --remove-port=1723/tcp
                firewall-cmd --permanent --remove-protocol=gre
                firewall-cmd --permanent --direct --remove-rule ipv4 filter FORWARD 0 -i ppp+ -j ACCEPT 2>/dev/null || true
                firewall-cmd --permanent --direct --remove-rule ipv4 filter FORWARD 0 -o ppp+ -j ACCEPT 2>/dev/null || true
                firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s 192.168.0.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE 2>/dev/null || true
                ;;
            "l2tp")
                firewall-cmd --permanent --remove-port=500/udp
                firewall-cmd --permanent --remove-port=4500/udp
                firewall-cmd --permanent --remove-port=1701/udp
                ;;
            "openvpn")
                firewall-cmd --permanent --remove-port=1194/udp
                firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE
                firewall-cmd --permanent --direct --remove-rule ipv4 filter FORWARD 0 -i tun+ -o "$MAIN_INTERFACE" -j ACCEPT
                firewall-cmd --permanent --direct --remove-rule ipv4 filter FORWARD 0 -i "$MAIN_INTERFACE" -o tun+ -j ACCEPT
                ;;
        esac
    fi
    firewall-cmd --reload
}

# PPTP 安装
install_pptp() {
    echo "正在安装 PPTP VPN 服务..."
    yum install -y pptpd ppp
    systemctl enable pptpd

    cat > /etc/pptpd.conf << EOF
option /etc/ppp/options.pptpd
logwtmp
localip 192.168.0.1
remoteip 192.168.0.100-200
EOF

    cat > /etc/ppp/options.pptpd << EOF
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

    # 加载GRE模块 - 关键修复
    echo "modprobe nf_conntrack_pptp" >> /etc/rc.local
    echo "modprobe nf_nat_pptp" >> /etc/rc.local
    modprobe nf_conntrack_pptp 2>/dev/null
    modprobe nf_nat_pptp 2>/dev/null

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

    # 检查TUN/TAP支持
    if [ ! -e /dev/net/tun ]; then
        echo "错误: 系统不支持TUN/TAP，无法安装L2TP VPN"
        return 1
    fi

    # 禁用SELinux (如果存在)
    if command -v setenforce >/dev/null 2>&1; then
        setenforce 0 2>/dev/null
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 2>/dev/null
    fi

    # 获取用户配置
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

    # 安装依赖
    yum install -y epel-release
    yum install -y gcc make flex bison ppp iptables libnss3-devel libnspr4-devel \
                   libcap-ng-devel libevent-devel libcurl-devel unbound-devel \
                   xmlto libunbound-devel curl wget xl2tpd

    # 尝试直接安装libreswan，如果失败则从源码编译
    if ! yum install -y libreswan; then
        echo "通过yum安装libreswan失败，尝试从源码编译..."

        # 安装编译依赖
        yum install -y nspr-devel nss-devel gmp-devel flex bison

        # 下载并编译Libreswan
        cd /tmp
        LIBRESWAN_VER=$(curl -s https://api.github.com/repos/libreswan/libreswan/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
        if [ -z "$LIBRESWAN_VER" ]; then
            LIBRESWAN_VER="4.12"
        fi

        wget -O libreswan.tar.gz "https://github.com/libreswan/libreswan/archive/v${LIBRESWAN_VER}.tar.gz"
        tar xzf libreswan.tar.gz
        cd "libreswan-${LIBRESWAN_VER}"

        # 配置编译选项
        cat > Makefile.inc.local << EOF
WERROR_CFLAGS =
USE_DNSSEC = false
USE_DH31 = false
USE_NSS_AVA_COPY = true
USE_NSS_IPSEC_PROFILE = false
USE_GLIBC_KERN_FLIP_HEADERS = true
EOF

        # 编译安装并检查是否成功
        if ! make programs && make install; then
            echo "Libreswan编译安装失败，请检查系统环境或网络连接。"
            return 1
        fi
    fi

    systemctl enable ipsec
    systemctl enable xl2tpd

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

    # 添加用户
    echo "${l2tp_user} l2tpd ${l2tp_password} *" >> /etc/ppp/chap-secrets

    # 配置系统网络设置 (基于Teddysun脚本的完整配置)
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

    # 启动服务
    systemctl restart ipsec
    systemctl restart xl2tpd

    # 配置防火墙
    configure_firewall "l2tp"

    # 验证安装
    echo "正在验证L2TP/IPsec安装..."
    if command -v ipsec >/dev/null 2>&1; then
        ipsec verify
    fi

    echo ""
    echo "=========================================="
    echo "L2TP/IPsec VPN 服务安装完成！"
    echo "=========================================="
    echo "服务器IP: $(curl -s ipinfo.io/ip || curl -s icanhazip.com || hostname -I | awk '{print $1}')"
    echo "预共享密钥(PSK): ${mypsk}"
    echo "用户名: ${l2tp_user}"
    echo "密码: ${l2tp_password}"
    echo "IP地址池: ${iprange}.2-${iprange}.254"
    echo ""
    echo "请在客户端配置L2TP/IPsec连接时使用以上信息。"
    echo "=========================================="
}

# OpenVPN 安装
install_openvpn() {
    echo "正在安装 OpenVPN 服务..."
    yum install -y openvpn easy-rsa
    mkdir -p /etc/openvpn/easy-rsa/keys
    # 查找easy-rsa实际安装路径
    EASYRSA_PATH=$(find /usr/share -name "easyrsa" -type f 2>/dev/null | head -1)
    if [ -n "$EASYRSA_PATH" ]; then
        EASYRSA_DIR=$(dirname "$EASYRSA_PATH")
        cp -r "$EASYRSA_DIR"/* /etc/openvpn/easy-rsa/
    else
        # 尝试复制整个easy-rsa目录
        if [ -d "/usr/share/easy-rsa" ]; then
            cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
        fi
    fi

    cd /etc/openvpn/easy-rsa/

    # 查找easyrsa可执行文件
    if [ ! -f "./easyrsa" ]; then
        # 尝试从系统路径找到easyrsa
        EASYRSA_BIN=$(which easyrsa 2>/dev/null || find /usr -name "easyrsa" -type f 2>/dev/null | head -1)
        if [ -n "$EASYRSA_BIN" ]; then
            ln -sf "$EASYRSA_BIN" ./easyrsa
        else
            echo "错误: 找不到easyrsa可执行文件"
            return 1
        fi
    fi

    # 检查easyrsa是否已在指定目录
    if [ ! -d "pki" ]; then
        ./easyrsa init-pki
    fi

    # 如果没有CA，则创建
    if [ ! -f "pki/ca.crt" ]; then
        echo "请确认证书信息，回车继续..."
        echo "" | ./easyrsa build-ca nopass
    fi

    # 生成服务器证书和密钥
    if [ ! -f "pki/issued/server.crt" ]; then
        echo "" | ./easyrsa gen-req server nopass
        echo "yes" | ./easyrsa sign-req server server
    fi

    # 生成DH参数
    if [ ! -f "pki/dh.pem" ]; then
        ./easyrsa gen-dh
    fi

    # 生成ta.key (HMAC防火墙)
    if [ ! -f "ta.key" ]; then
        openvpn --genkey --secret ta.key
    fi

    # 移动文件到OpenVPN目录
    if [ -f "pki/ca.crt" ] && [ -f "pki/issued/server.crt" ] && [ -f "pki/private/server.key" ] && [ -f "ta.key" ] && [ -f "pki/dh.pem" ]; then
        cp pki/ca.crt pki/issued/server.crt pki/private/server.key ta.key pki/dh.pem /etc/openvpn/
    else
        echo "错误: 证书文件生成失败，请检查上述错误信息"
        return 1
    fi

    # 创建OpenVPN服务器配置文件
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
group nobody
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

    # 检查服务状态
    if ! systemctl is-active --quiet openvpn@server; then
        echo "警告: OpenVPN服务启动失败，请检查配置"
        echo "运行以下命令查看详细错误:"
        echo "systemctl status openvpn@server"
        echo "journalctl -u openvpn@server"
    fi

    configure_firewall "openvpn"

    echo "OpenVPN 服务安装完成！"
    echo "下一步是生成客户端配置文件。"
    read -p "是否现在生成OpenVPN客户端配置文件？(y/n): " gen_client
    if [[ "$gen_client" == "y" || "$gen_client" == "Y" ]]; then
        generate_openvpn_client
    fi
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
    yum remove -y pptpd
    rm -f /etc/pptpd.conf /etc/ppp/options.pptpd
    sed -i "/ pptpd /d" /etc/ppp/chap-secrets

    # 清理GRE模块加载配置
    sed -i '/modprobe nf_conntrack_pptp/d' /etc/rc.local
    sed -i '/modprobe nf_nat_pptp/d' /etc/rc.local

    # 清理sysctl配置
    sed -i '/net.ipv4.ip_forward = 1/d' /etc/sysctl.conf
    sysctl -p

    configure_firewall "pptp" "remove"
    echo "PPTP VPN 服务已卸载。"
}

uninstall_l2tp() {
    echo "正在卸载 L2TP/IPsec VPN 服务..."
    systemctl stop xl2tpd ipsec
    systemctl disable xl2tpd ipsec
    yum remove -y libreswan xl2tpd
    rm -f /etc/ipsec.conf
    rm -f /etc/ipsec.secrets
    rm -f /etc/xl2tpd/xl2tpd.conf
    rm -f /etc/ppp/options.xl2tpd
    sed -i "/ l2tpd /d" /etc/ppp/chap-secrets # 移除所有L2TP用户
    # 清理sysctl配置
    sed -i '/net.ipv4.ip_forward = 1/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.send_redirects = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.send_redirects = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.accept_redirects = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.accept_redirects = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.accept_source_route = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.accept_source_route = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.rp_filter = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.rp_filter = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.lo.rp_filter = 0/d' /etc/sysctl.conf
    sed -i "/net.ipv4.conf.${MAIN_INTERFACE}.rp_filter = 0/d" /etc/sysctl.conf
    sysctl -p
    configure_firewall "l2tp" "remove"
    echo "L2TP/IPsec VPN 服务已卸载。"
}

uninstall_openvpn() {
    echo "正在卸载 OpenVPN 服务..."
    systemctl stop openvpn@server
    systemctl disable openvpn@server
    yum remove -y openvpn easy-rsa
    rm -rf /etc/openvpn/*
    # 移除sysctl转发配置
    sed -i '/net.ipv4.ip_forward = 1/d' /etc/sysctl.conf
    sysctl -p
    configure_firewall "openvpn" "remove"
    echo "OpenVPN 服务已卸载。"
}

# L2TP用户管理函数
manage_l2tp_users() {
    echo "----------------------------------------"
    echo "       L2TP 用户管理"
    echo "----------------------------------------"
    echo "1. 列出所有用户"
    echo "2. 添加用户"
    echo "3. 删除用户"
    echo "4. 修改用户密码"
    echo "0. 返回主菜单"
    echo "----------------------------------------"

    read -p "请选择操作: " user_option

    case $user_option in
        1)
            echo "当前L2TP用户列表:"
            echo "----------------------------------------"
            if [ -f /etc/ppp/chap-secrets ]; then
                grep " l2tpd " /etc/ppp/chap-secrets | awk '{print "用户名: " $1 "  密码: " $3}'
            else
                echo "未找到用户配置文件"
            fi
            ;;
        2)
            read -p "请输入新用户名: " new_user
            read -p "请输入新密码: " new_pass
            if [ -n "$new_user" ] && [ -n "$new_pass" ]; then
                echo "$new_user l2tpd $new_pass *" >> /etc/ppp/chap-secrets
                echo "用户 $new_user 添加成功"
            else
                echo "用户名和密码不能为空"
            fi
            ;;
        3)
            read -p "请输入要删除的用户名: " del_user
            if [ -n "$del_user" ]; then
                sed -i "/^$del_user l2tpd /d" /etc/ppp/chap-secrets
                echo "用户 $del_user 删除成功"
            else
                echo "用户名不能为空"
            fi
            ;;
        4)
            read -p "请输入要修改密码的用户名: " mod_user
            read -p "请输入新密码: " mod_pass
            if [ -n "$mod_user" ] && [ -n "$mod_pass" ]; then
                sed -i "/^$mod_user l2tpd /c\\$mod_user l2tpd $mod_pass *" /etc/ppp/chap-secrets
                echo "用户 $mod_user 密码修改成功"
            else
                echo "用户名和密码不能为空"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo "无效选项"
            ;;
    esac

    read -p "按任意键继续..."
    manage_l2tp_users
}

# 主菜单
main_menu() {
    install_dependencies

    clear
    echo "----------------------------------------"
    echo "       CentOS VPN 服务管理脚本"
    echo "----------------------------------------"
    echo "1. 安装 PPTP VPN"
    echo "2. 卸载 PPTP VPN"
    echo "3. 安装 L2TP/IPsec VPN"
    echo "4. 卸载 L2TP/IPsec VPN"
    echo "5. L2TP 用户管理"
    echo "6. 安装 OpenVPN"
    echo "7. 卸载 OpenVPN"
    echo "8. 生成 OpenVPN 客户端配置"
    echo "0. 退出"
    echo "----------------------------------------"

    read -p "请选择一个选项: " option

    case $option in
        1) install_pptp ;;
        2) uninstall_pptp ;;
        3) install_l2tp ;;
        4) uninstall_l2tp ;;
        5) manage_l2tp_users ;;
        6) install_openvpn ;;
        7) uninstall_openvpn ;;
        8) generate_openvpn_client ;;
        0) echo "脚本已退出。"; exit 0 ;;
        *) echo "无效的选项，请重新选择。"; sleep 2; main_menu ;;
    esac

    read -p "按任意键返回主菜单..."
    main_menu
}

# 运行主菜单
main_menu