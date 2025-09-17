## 一些用 AI 写的脚本

> **国内用户推荐**: 查看 [README-gitee.md](README-gitee.md) 获取 Gitee 镜像链接

### 🚀 快速开始

#### Docker 环境搭建

**CentOS/RHEL/Fedora 系统:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker-centos.sh)
```

**Ubuntu/Debian 系统:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker-ubuntu.sh)
```

#### 常用服务安装
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker_services.sh)
```

#### VPN 服务搭建

**CentOS/RHEL/Fedora 系统:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-centos.sh)
```

**Ubuntu/Debian 系统:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-ubuntu.sh)
```

#### 邮件服务器
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/email/email-centos.sh)
```

### 📁 目录结构

```
shbat/
├── docker/              # Docker 相关脚本
│   ├── docker-centos.sh # CentOS/RHEL/Fedora Docker 管理
│   ├── docker-ubuntu.sh # Ubuntu/Debian Docker 管理
│   └── docker_services.sh # 服务安装脚本
├── email/               # 邮件服务脚本
│   └── email-centos.sh  # CentOS 邮件服务器配置
├── vpn/                 # VPN 服务脚本
│   ├── vpn-centos.sh    # CentOS/RHEL/Fedora VPN 配置
│   └── vpn-ubuntu.sh    # Ubuntu/Debian VPN 配置
├── CODEBUDDY.md         # 开发文档
├── README.md            # 本文件
└── README-gitee.md      # Gitee 专用说明
```

### ✨ 功能特点

- **交互式菜单**: 友好的命令行界面
- **多发行版支持**: 针对 CentOS/RHEL/Fedora 和 Ubuntu/Debian 优化
- **自动配置**: 防火墙、网络和安全设置
- **服务管理**: Docker 容器、VPN 协议、邮件服务
- **国内优化**: 包含中国大陆网络优化（Docker 镜像源等）

### 📋 系统要求

- Linux 系统 (CentOS/RHEL 7+, Ubuntu 18.04+, Debian 9+)
- Root 权限
- 网络连接

### ⚠️ 注意事项

- 所有脚本需要 root 权限运行
- 脚本会修改系统配置
- 建议先在测试环境中验证
- 包含自动防火墙配置
- 运行前请备份重要数据

### 🔗 镜像地址

- **GitHub**: https://github.com/Dudo-m/shbat
- **Gitee** (国内): https://gitee.com/LI_li_plus/shbat

**国内用户推荐**: 查看 [README-gitee.md](README-gitee.md) 获取完整的 Gitee 链接和使用说明。