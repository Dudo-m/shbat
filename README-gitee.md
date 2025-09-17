## 一些用 AI 写的脚本 (Gitee 镜像版)

> **本文档专为国内用户提供 Gitee 镜像链接，网络访问更稳定**

### 📁 Docker 相关脚本

#### Docker 管理脚本 (CentOS/RHEL/Fedora)
**功能**: Docker 安装、配置、容器管理、镜像操作

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker-centos.sh)
```

#### Docker 管理脚本 (Ubuntu/Debian)
**功能**: Docker 安装、配置、容器管理、镜像操作

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker-ubuntu.sh)
```

#### 常用服务安装脚本 (docker/docker_services.sh)
**功能**: 一键安装 Redis、MySQL、PostgreSQL、Nginx、Elasticsearch 等服务

**Gitee:**
```bash
curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker_services.sh | bash
```

### 📧 邮件服务脚本

#### CentOS 邮件服务器脚本 (email/email-centos.sh)
**功能**: Postfix + Dovecot 邮件服务器配置，支持 SMTP、POP3、IMAP

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/email/email-centos.sh)
```

### 🔒 VPN 服务脚本

#### CentOS 专用 VPN 脚本 (vpn/vpn-centos.sh)
**功能**: 针对 CentOS/RHEL/Fedora 优化，使用 firewalld + yum

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn-centos.sh)
```

#### Ubuntu 专用 VPN 脚本 (vpn/vpn-ubuntu.sh)
**功能**: 针对 Ubuntu/Debian 优化，使用 ufw + apt

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
├── docker/              # Docker 相关脚本
│   ├── docker-centos.sh # CentOS Docker 管理
│   ├── docker-ubuntu.sh # Ubuntu Docker 管理
│   └── docker_services.sh # 服务安装脚本
├── email/               # 邮件服务脚本  
│   └── email-centos.sh  # CentOS 邮件服务器
├── vpn/                 # VPN 服务脚本
│   ├── vpn-centos.sh    # CentOS VPN 服务
│   └── vpn-ubuntu.sh    # Ubuntu VPN 服务
├── CODEBUDDY.md         # 开发文档
├── README.md            # 国际版说明
└── README-gitee.md      # 中文版说明 (本文件)
```

## 🚀 快速开始

### Docker 环境搭建

**CentOS/RHEL/Fedora 系统:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker-centos.sh)
```

**Ubuntu/Debian 系统:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker-ubuntu.sh)
```

### 常用服务部署
```bash
curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker_services.sh | bash
```

### VPN 服务搭建

**CentOS 系统:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn-centos.sh)
```

**Ubuntu 系统:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn-ubuntu.sh)
```

## ⚠️ 注意事项

- 脚本会修改系统配置，建议先备份重要数据
- 首次运行建议在测试环境中验证
- 脚本包含中国大陆网络优化（Docker 镜像源等）
- 支持防火墙自动配置（firewalld/ufw）