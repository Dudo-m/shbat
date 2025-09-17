#!/bin/bash

#==============================================
# CentOS 7 邮件服务器配置脚本
# 支持: SMTP (Postfix), POP3/IMAP (Dovecot)
#==============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印带颜色的消息
print_msg() {
    echo -e "${2}${1}${NC}"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_msg "错误: 此脚本必须以root权限运行!" "$RED"
        exit 1
    fi
}

# 安装软件包
install_packages() {
    print_msg "安装邮件服务软件包..." "$YELLOW"
    yum install -y postfix dovecot
    systemctl stop sendmail &>/dev/null || true
    systemctl disable sendmail &>/dev/null || true
}

# 获取域名配置
get_domain_config() {
    print_msg "配置邮件域名..." "$BLUE"

    read -p "请输入邮件域名 (例如: xiaoqi.com): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        print_msg "域名不能为空!" "$RED"
        read -p "请输入邮件域名: " DOMAIN
    done

    read -p "请输入邮件服务器主机名 (默认: mail.$DOMAIN): " MAIL_HOSTNAME
    if [[ -z "$MAIL_HOSTNAME" ]]; then
        MAIL_HOSTNAME="mail.$DOMAIN"
    fi

    print_msg "配置信息:" "$GREEN"
    echo "  域名: $DOMAIN"
    echo "  主机名: $MAIL_HOSTNAME"

    read -p "确认以上信息正确? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        get_domain_config
    fi
}

# 配置Postfix
configure_postfix() {
    print_msg "配置Postfix..." "$YELLOW"

    # 备份原配置
    cp /etc/postfix/main.cf /etc/postfix/main.cf.backup

    # 注释掉可能冲突的配置
    sed -i 's/^myhostname/#&/' /etc/postfix/main.cf
    sed -i 's/^mydomain/#&/' /etc/postfix/main.cf
    sed -i 's/^myorigin/#&/' /etc/postfix/main.cf
    sed -i 's/^inet_interfaces/#&/' /etc/postfix/main.cf
    sed -i 's/^inet_protocols/#&/' /etc/postfix/main.cf
    sed -i 's/^mydestination/#&/' /etc/postfix/main.cf
    sed -i 's/^home_mailbox/#&/' /etc/postfix/main.cf

    # 添加新配置
    cat >> /etc/postfix/main.cf << EOF

#-----------自定义配置------------
#邮件服务器的主机名
myhostname = $MAIL_HOSTNAME
#邮件域,@后面的域名
mydomain = $DOMAIN
#往外发邮件的邮件域
myorigin = \$mydomain
#监听的网卡
inet_interfaces = all
inet_protocols = all
#服务的对象
mydestination = \$myhostname,\$mydomain
#邮件存放的目录
home_mailbox = Maildir/
#允许中继的网络
mynetworks = 127.0.0.0/8,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8
#SMTP认证
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous
#中继限制
smtpd_relay_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination
EOF

    print_msg "Postfix配置完成!" "$GREEN"
}

# 配置Dovecot
configure_dovecot() {
    print_msg "配置Dovecot..." "$YELLOW"

    # 备份原配置
    cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.backup

    # 注释掉可能冲突的配置
    sed -i 's/^protocols/#&/' /etc/dovecot/dovecot.conf
    sed -i 's/^listen/#&/' /etc/dovecot/dovecot.conf

# 添加新配置
    cat >> /etc/dovecot/dovecot.conf << 'EOF'

#-----------自定义配置------------
protocols = imap pop3 lmtp
listen = *, ::
ssl = no
disable_plaintext_auth = no
mail_location = maildir:~/Maildir

#SASL认证配置
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}

auth_mechanisms = plain login
passdb {
  driver = pam
}
userdb {
  driver = passwd
}
EOF

    print_msg "Dovecot配置完成!" "$GREEN"
}

# 配置防火墙
configure_firewall() {
    print_msg "配置防火墙..." "$YELLOW"

    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=smtp
        firewall-cmd --permanent --add-service=pop3
        firewall-cmd --permanent --add-service=imap
        firewall-cmd --reload
        print_msg "防火墙配置完成!" "$GREEN"
    else
        print_msg "防火墙未运行，跳过配置" "$YELLOW"
    fi
}

# 启动服务
start_services() {
    print_msg "启动邮件服务..." "$YELLOW"

    systemctl restart postfix
    systemctl enable postfix
    systemctl restart dovecot
    systemctl enable dovecot

    print_msg "服务启动完成!" "$GREEN"
}

# 创建邮件用户
create_mail_user() {
    print_msg "创建邮件用户..." "$YELLOW"

    read -p "请输入要创建的用户名: " USERNAME
    if [[ -z "$USERNAME" ]]; then
        print_msg "用户名不能为空!" "$RED"
        return 1
    fi

    if id "$USERNAME" &>/dev/null; then
        print_msg "用户 $USERNAME 已存在!" "$YELLOW"
        return 1
    fi

    # 创建用户
    useradd "$USERNAME"

    # 设置密码
    read -s -p "请输入密码: " PASSWORD
    echo
    echo "$PASSWORD" | passwd --stdin "$USERNAME"

    # 创建邮件目录
    mkdir -p /home/$USERNAME/Maildir/{new,cur,tmp}
    chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir
    chmod -R 700 /home/$USERNAME/Maildir

    # 获取域名
    local domain=$(postconf -h mydomain 2>/dev/null || echo "localhost")
    print_msg "用户 $USERNAME@$domain 创建成功!" "$GREEN"
}

# 测试服务
test_services() {
    print_msg "测试服务状态..." "$YELLOW"

    if systemctl is-active --quiet postfix; then
        print_msg "✓ Postfix 运行正常" "$GREEN"
    else
        print_msg "✗ Postfix 未运行" "$RED"
    fi

    if systemctl is-active --quiet dovecot; then
        print_msg "✓ Dovecot 运行正常" "$GREEN"
    else
        print_msg "✗ Dovecot 未运行" "$RED"
    fi

    print_msg "端口监听状态:" "$YELLOW"
    ss -tlnp | grep -E ':25|:110|:143' || netstat -tlnp | grep -E ':25|:110|:143'
}

# 显示使用信息
show_info() {
    print_msg "\n===== 邮件服务器配置完成 ====" "$BLUE"
    echo ""
    if [[ -n "$DOMAIN" ]]; then
        print_msg "域名: $DOMAIN" "$GREEN"
        print_msg "主机名: $MAIL_HOSTNAME" "$GREEN"
    else
        # 从配置文件读取
        local domain=$(postconf -h mydomain 2>/dev/null)
        local hostname=$(postconf -h myhostname 2>/dev/null)
        print_msg "域名: $domain" "$GREEN"
        print_msg "主机名: $hostname" "$GREEN"
    fi
    echo ""
    print_msg "服务端口:" "$YELLOW"
    echo "  SMTP: 25"
    echo "  POP3: 110"
    echo "  IMAP: 143"
    echo ""
    print_msg "测试连接:" "$YELLOW"
    echo "  telnet localhost 110"
    echo "  user 用户名"
    echo "  pass 密码"
}

# 卸载邮件服务器
uninstall_mail_server() {
    print_msg "\n===== 卸载邮件服务器 ====" "$BLUE"
    print_msg "警告: 此操作将完全删除邮件服务器及其配置!" "$RED"
    read -p "确定要卸载吗? (yes/no): " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        print_msg "取消卸载" "$YELLOW"
        return
    fi

    print_msg "停止服务..." "$YELLOW"
    systemctl stop postfix dovecot &>/dev/null
    systemctl disable postfix dovecot &>/dev/null

    print_msg "卸载软件包..." "$YELLOW"
    yum remove -y postfix dovecot &>/dev/null

    print_msg "恢复配置文件..." "$YELLOW"
    if [[ -f /etc/postfix/main.cf.backup ]]; then
        mv /etc/postfix/main.cf.backup /etc/postfix/main.cf
    fi
    if [[ -f /etc/dovecot/dovecot.conf.backup ]]; then
        mv /etc/dovecot/dovecot.conf.backup /etc/dovecot/dovecot.conf
    fi

    # 清理防火墙规则
    if systemctl is-active --quiet firewalld; then
        print_msg "移除防火墙规则..." "$YELLOW"
        firewall-cmd --permanent --remove-service=smtp &>/dev/null
        firewall-cmd --permanent --remove-service=pop3 &>/dev/null
        firewall-cmd --permanent --remove-service=imap &>/dev/null
        firewall-cmd --reload &>/dev/null
    fi

    print_msg "邮件服务器卸载完成!" "$GREEN"
}

# 主菜单
show_menu() {
    clear
    print_msg "================================" "$BLUE"
    print_msg "   简化版邮件服务器配置脚本" "$BLUE"
    print_msg "================================" "$BLUE"
    echo ""
    print_msg "1. 安装配置邮件服务器" "$GREEN"
    print_msg "2. 创建邮件用户" "$GREEN"
    print_msg "3. 测试服务状态" "$GREEN"
    print_msg "4. 卸载邮件服务器" "$RED"
    print_msg "0. 退出" "$YELLOW"
    echo ""
    read -p "请选择操作 [0-4]: " choice
}

# 安装主流程
install_mail_server() {
    print_msg "开始配置邮件服务器..." "$GREEN"

    get_domain_config
    install_packages
    configure_postfix
    configure_dovecot
    configure_firewall
    start_services

    print_msg "邮件服务器配置完成!" "$GREEN"
    show_info
}

# 主程序
main() {
    check_root

    while true; do
        show_menu
        case $choice in
            1)
                install_mail_server
                read -p "按回车键继续..."
                ;;
            2)
                create_mail_user
                read -p "按回车键继续..."
                ;;
            3)
                test_services
                read -p "按回车键继续..."
                ;;
            4)
                uninstall_mail_server
                read -p "按回车键继续..."
                ;;
            0)
                print_msg "退出脚本" "$YELLOW"
                exit 0
                ;;
            *)
                print_msg "无效选择!" "$RED"
                sleep 2
                ;;
        esac
    done
}

# 运行主程序
main
