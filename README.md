# System Administration Scripts

> **中文用户请查看**: [README-gitee.md](README-gitee.md) | **For Chinese users**: [README-gitee.md](README-gitee.md)

AI-generated shell scripts for system administration and service deployment on Linux systems (CentOS/RHEL and Ubuntu/Debian).

## 🚀 Quick Start

### Docker Management
```bash
# CentOS/RHEL/Fedora
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker-centos.sh)

# Ubuntu/Debian
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker-ubuntu.sh)
```

### Service Installation
```bash
# Install Redis, MySQL, PostgreSQL, Nginx, Elasticsearch, etc.
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker_services.sh)
```

### VPN Setup
```bash
# CentOS/RHEL/Fedora
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-centos.sh)

# Ubuntu/Debian
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-ubuntu.sh)
```

### Email Server
```bash
# CentOS Email Server (Postfix + Dovecot)
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/email/email-centos.sh)
```

## 📁 Repository Structure

```
shbat/
├── docker/              # Docker management scripts
│   ├── docker-centos.sh # CentOS/RHEL/Fedora Docker management
│   ├── docker-ubuntu.sh # Ubuntu/Debian Docker management
│   └── docker_services.sh # Service installation script
├── email/               # Email server scripts
│   └── email-centos.sh  # CentOS email server setup
├── vpn/                 # VPN service scripts
│   ├── vpn-centos.sh    # CentOS/RHEL/Fedora VPN setup
│   └── vpn-ubuntu.sh    # Ubuntu/Debian VPN setup
├── CODEBUDDY.md         # Development documentation
├── README.md            # This file
└── README-gitee.md      # Chinese documentation
```

## ✨ Features

- **Interactive Menus**: User-friendly command-line interfaces
- **Multi-Distribution Support**: Optimized for CentOS/RHEL/Fedora and Ubuntu/Debian
- **Automatic Configuration**: Firewall, network, and security setup
- **Service Management**: Docker containers, VPN protocols, email services
- **Chinese Mirror Support**: Optimized for users in mainland China

## 📋 Requirements

- Linux system (CentOS/RHEL 7+, Ubuntu 18.04+, Debian 9+)
- Root privileges
- Internet connection

## ⚠️ Important Notes

- All scripts require root privileges
- Scripts will modify system configurations
- Recommended to test in a virtual environment first
- Automatic firewall configuration included
- Backup important data before running

## 🔗 Mirrors

- **GitHub**: https://github.com/Dudo-m/shbat
- **Gitee** (China): https://gitee.com/LI_li_plus/shbat

For detailed Chinese documentation and Gitee links, see [README-gitee.md](README-gitee.md).