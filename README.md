## 一些用 AI 写的脚本

> 国内用户推荐阅读 [README-gitee.md](README-gitee.md) 使用 Gitee 镜像链接

### 🚀 快速开始（直接运行或下载后运行）

- Docker 环境脚本（自动识别 CentOS/RHEL/Fedora/Ubuntu/Debian）
  - 直接运行：
    ```bash
    bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker.sh)
    ```
  - 下载后运行：
    ```bash
    curl -LO https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker.sh
    bash docker.sh
    ```

- 常用服务安装
  ```bash
  curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker_services.sh | bash
  # 或下载：curl -LO https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker_services.sh && bash docker_services.sh
  ```

- VPN（CentOS/RHEL/Fedora）
  ```bash
  bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-centos.sh)
  # 或下载：curl -LO https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-centos.sh && bash vpn-centos.sh
  ```

- 邮件服务（CentOS）
  ```bash
  bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/email/email-centos.sh)
  # 或下载：curl -LO https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/email/email-centos.sh && bash email-centos.sh
  ```

- 自签证书
  ```bash
  bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/cert/cert.sh)
  # 或下载：curl -LO https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/cert/cert.sh && bash cert.sh
  ```

- DictAdmin 代理小工具
  ```bash
  bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/dictadmin/px.sh)
  # 旁路：bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/dictadmin/px-sb.sh)
  ```

- Python UDP/TCP 网络测试
  ```bash
  curl -LO https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/udptcp-py/net_tool.py
  python3 net_tool.py --help
  ```

- Sub-Store 节点 GeoIP 自动改名
  - 在 Sub-Store 中新建「脚本操作 → 重命名」脚本，填入：
    ```text
    https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/substore/geoip-rename.js
    ```
  - 功能：自动探测节点 IP 归属地，重命名为 `国家|地区|协议|编号|原始名称`
  - 示例：`日本|东京|tuic|01|Oracel-tuic-instance-20260719-2025`

### 📌 gs-netcat 说明

- 二进制请从上游下载：https://github.com/hackerschoice/gsocket/releases
- 使用说明见 `gs-netcat/README.md`（本仓库不包含二进制）。

### 📁 目录结构

```
shbat/
├── docker/       # Docker 脚本（环境/常用服务）
├── email/        # 邮件服务脚本（CentOS）
├── vpn/          # VPN 脚本（CentOS/RHEL/Fedora）
├── cert/         # 自签证书脚本
├── dictadmin/    # 轻量代理脚本
├── udptcp-py/    # Python 网络测试工具
├── substore/     # Sub-Store 节点 GeoIP 自动改名脚本
├── gs-netcat/    # gs-netcat 使用示例脚本
```

### ⚠️ 注意

- 需 root 权限；脚本会修改系统配置，建议先在测试环境使用。
- 优先在 Linux/Bash 环境执行；Windows 建议使用 WSL 或 Linux 虚拟机。

### 🔗 项目地址

- GitHub: https://github.com/Dudo-m/shbat
- Gitee（国内镜像）: https://gitee.com/LI_li_plus/shbat
