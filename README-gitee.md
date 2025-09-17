## 一些用 AI 写的脚本 (Gitee 镜像版)

> **本文档专为国内用户提供 Gitee 镜像链接，网络访问更稳定**

### 🚀 快速开始

#### Docker 环境搭建 (通用)

此脚本会自动检测您的系统 (CentOS/RHEL/Fedora/Ubuntu/Debian) 并执行相应的操作。

**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker.sh)
```

#### 常用服务安装
**Gitee:**
```bash
curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/docker/docker_services.sh | bash
```

#### VPN 服务搭建

**CentOS/RHEL/Fedora 系统:**
**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/vpn/vpn-centos.sh)
```

#### 邮件服务器
**Gitee:**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/email/email-centos.sh)
```

### 📁 目录结构

```
shbat/
├── docker/              # Docker 相关脚本
│   ├── docker.sh        # 通用 Docker 环境管理脚本 (推荐)
│   └── docker_services.sh # 常用服务安装脚本
├── email/               # 邮件服务脚本
│   └── email-centos.sh  # CentOS 邮件服务器配置
├── vpn/                 # VPN 服务脚本
│   └── vpn-centos.sh    # CentOS/RHEL/Fedora VPN 配置
├── README.md            # GitHub 版说明
└── README-gitee.md      # Gitee 专用说明 (本文件)
```

### ✨ 功能特点

- **通用性**: 一个脚本支持 CentOS/RHEL/Fedora 和 Ubuntu/Debian。
- **交互式菜单**: 友好的命令行界面，提供丰富的功能选项。
- **全面的Docker管理**:
  - 安装、卸载、配置镜像加速。
  - 容器管理 (启动、停止、删除)。
  - 镜像管理 (导入、导出)。
  - 系统清理和状态检查。
- **国内优化**: 包含中国大陆网络优化（apt/yum源、Docker 镜像源等）。
- **自动配置**: 防火墙、网络和安全设置。

### 📋 系统要求

- Linux 系统 (CentOS/RHEL 7+, Ubuntu 18.04+, Debian 9+, Fedora)
- Root 权限
- 网络连接

### ⚠️ 注意事项

- 所有脚本需要 root 权限运行。
- 脚本会修改系统配置，建议先在测试环境中验证。
- 运行前请备份重要数据。
