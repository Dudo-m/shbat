## 一些用 AI 写的脚本

### 📁 Docker 相关脚本

#### Docker 管理脚本 (docker/docker.sh)
**功能**: Docker 安装、配置、容器管理、镜像操作

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker.sh)
```

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker.sh)
```

#### 常用服务安装脚本 (docker/docker_services.sh)
**功能**: 一键安装 Redis、MySQL、PostgreSQL、Nginx、Elasticsearch 等服务

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker_services.sh)
```

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker_services.sh)
```

### 📧 邮件服务脚本

#### 邮件服务器安装脚本 (email/email.sh)
**功能**: Postfix + Dovecot 邮件服务器配置 (适用于 CentOS 7)

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/email/email.sh)
```

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/email/email.sh)
```

### 🔒 VPN 服务脚本

#### 通用 VPN 脚本 (vpn/vpn.sh)
**功能**: 支持 PPTP、L2TP/IPsec、OpenVPN，自动检测系统类型

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn.sh)
```

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn.sh)
```

#### CentOS 专用 VPN 脚本 (vpn/vpn-centos.sh)
**功能**: 针对 CentOS/RHEL/Fedora 优化，使用 firewalld + yum

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-centos.sh)
```

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn-centos.sh)
```

#### Ubuntu 专用 VPN 脚本 (vpn/vpn-ubuntu.sh)
**功能**: 针对 Ubuntu/Debian 优化，使用 ufw + apt

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-ubuntu.sh)
```

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn-ubuntu.sh)
```

## 📋 使用说明

- 所有脚本需要 root 权限运行
- 支持 CentOS/RHEL、Ubuntu/Debian 系统
- 脚本会自动安装依赖和配置防火墙
- 建议在全新系统上运行以避免冲突

## 🗂️ 目录结构

```
shbat/
├── docker/          # Docker 相关脚本
├── email/           # 邮件服务脚本  
├── vpn/             # VPN 服务脚本
├── CODEBUDDY.md     # 开发文档
└── README.md        # 使用说明
```