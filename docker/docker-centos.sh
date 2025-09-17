#!/bin/bash

# CentOS Docker管理脚本
# 版本: 4.1.1
# 描述: CentOS系统Docker环境管理工具

set -uo pipefail

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

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# 脚本版本
readonly SCRIPT_VERSION="4.1.1"

# Docker Compose稳定版本
readonly COMPOSE_FALLBACK_VERSION="v2.24.6"

# 国内Docker镜像源
readonly DOCKER_MIRRORS=(
    "https://docker.1panel.live"
    "https://docker.1ms.run"
    "https://hub.rat.dev"
    "https://docker.m.daocloud.io"
    "https://mirror.ccs.tencentyun.com"
    "https://reg-mirror.qiniu.com"
    "https://registry-docker-hub-mirror.g.bhn.sh"
    "https://docker.rainbond.cc"
)

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"
}

log_blue() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"
}

log_purple() {
    echo -e "${PURPLE}[STEP]${NC} $(date '+%H:%M:%S') $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查网络连接
check_network() {
    if ! curl -s --connect-timeout 5 --max-time 10 https://www.baidu.com >/dev/null 2>&1; then
        log_error "网络连接检查失败，请检查网络设置"
        return 1
    fi
}

# 确认操作函数
confirm_action() {
    local message="$1"
    local default="${2:-N}"

    if [[ "$default" == "Y" || "$default" == "y" ]]; then
        read -rp "$message [Y/n]: " confirm
        [[ -z "$confirm" || "$confirm" =~ ^[yY]$ ]]
    else
        read -rp "$message [y/N]: " confirm
        [[ "$confirm" =~ ^[yY]$ ]]
    fi
}

# 更新yum源为国内镜像
change_yum_source() {
    log_purple "配置yum国内镜像源..."

    # 备份原有配置
    local backup_dir="/etc/yum.repos.d/backup_$(date +%s)"
    mkdir -p "$backup_dir"
    mv /etc/yum.repos.d/*.repo "$backup_dir"/ 2>/dev/null || true
    log_info "已备份原repo文件到: $backup_dir"

    # 获取系统版本
    local version
    version=$(rpm -q --qf "%{VERSION}" centos-release 2>/dev/null || echo "8")

    # 创建阿里云CentOS源
    cat > /etc/yum.repos.d/CentOS-Base.repo <<EOF
# 阿里云CentOS镜像源 - 自动生成于$(date)
[base]
name=CentOS-\$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-$version

[updates]
name=CentOS-\$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-$version

[extras]
name=CentOS-\$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-$version
EOF

    log_info "清理并更新缓存..."
    if command_exists dnf; then
        dnf clean all && dnf makecache
    else
        yum clean all && yum makecache fast
    fi

    log_info "yum源配置完成！"
}

# 安装系统依赖
install_dependencies() {
    log_purple "安装系统依赖包..."
    
    yum update -y
    yum install -y yum-utils device-mapper-persistent-data lvm2 curl wget
}

# 安装Docker
install_docker() {
    log_purple "开始安装Docker..."

    if command_exists docker; then
        log_warn "Docker已安装，版本信息："
        docker --version
        return 0
    fi

    echo
    log_info "请选择Docker安装源："
    log_info "  1) 官方源（默认）"
    log_info "  2) 国内源（推荐国内用户选择）"
    echo
    read -rp "请输入选择 (1/2，默认为1): " source_choice
    echo

    case "${source_choice:-1}" in
        2)
            log_info "使用国内源安装Docker..."
            install_docker_cn
            ;;
        *)
            log_info "使用官方源安装Docker..."
            install_docker_official
            ;;
    esac
}

# Docker官方源安装
install_docker_official() {
    check_network
    install_dependencies

    if command_exists dnf; then
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    else
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    fi

    systemctl start docker
    systemctl enable docker

    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "已将用户 $SUDO_USER 添加到docker组，请重新登录生效"
    fi

    log_info "Docker安装完成！"
    docker --version
}

# Docker国内源安装
install_docker_cn() {
    check_network
    install_dependencies

    if command_exists dnf; then
        dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    else
        yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    fi

    systemctl start docker
    systemctl enable docker

    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "已将用户 $SUDO_USER 添加到docker组，请重新登录生效"
    fi

    log_info "Docker安装完成！"
    docker --version
}

# 获取最新Docker Compose版本
get_latest_compose_version() {
    local version
    version=$(curl -s --connect-timeout 10 --max-time 15 \
        "https://api.github.com/repos/docker/compose/releases/latest" 2>/dev/null | \
        grep -o '"tag_name": *"[^"]*"' | \
        grep -o '[^"]*$' | \
        head -1)

    if [[ -z "$version" ]]; then
        log_warn "无法获取最新版本，使用备用版本: $COMPOSE_FALLBACK_VERSION"
        version="$COMPOSE_FALLBACK_VERSION"
    else
        log_info "获取到最新版本: $version"
    fi

    echo "$version"
}

# 安装Docker Compose
install_docker_compose() {
    log_purple "开始安装Docker Compose..."

    if command_exists docker-compose; then
        log_warn "Docker Compose已安装，版本信息："
        docker-compose --version
        return 0
    fi

    echo
    log_info "请选择Docker Compose安装方式："
    log_info "  1) 官方源（默认）"
    log_info "  2) 包管理器安装"
    echo
    read -rp "请输入选择 (1/2，默认为1): " source_choice
    echo

    case "${source_choice:-1}" in
        2)
            log_info "使用包管理器安装Docker Compose..."
            install_compose_via_package_manager
            ;;
        *)
            log_info "使用官方源安装Docker Compose..."
            install_docker_compose_official
            ;;
    esac
}

# Docker Compose官方源安装
install_docker_compose_official() {
    check_network

    local version
    version=$(get_latest_compose_version)

    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    case $arch in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        armv7l) arch="armv7" ;;
        *) log_error "不支持的架构: $arch"; return 1 ;;
    esac

    log_info "下载Docker Compose $version for $os-$arch..."

    local download_url="https://github.com/docker/compose/releases/download/${version}/docker-compose-${os}-${arch}"

    if curl -L --fail --show-error --progress-bar \
        "$download_url" -o /usr/local/bin/docker-compose; then
        chmod +x /usr/local/bin/docker-compose
        log_info "Docker Compose安装完成！"
        docker-compose --version
    else
        log_error "Docker Compose下载失败"
        return 1
    fi
}

# 通过包管理器安装Docker Compose
install_compose_via_package_manager() {
    check_network
    
    log_info "尝试通过系统包管理器安装..."

    if command_exists dnf; then
        if dnf install -y docker-compose-plugin; then
            if [[ ! -f /usr/local/bin/docker-compose ]]; then
                cat > /usr/local/bin/docker-compose <<'EOF'
#!/bin/bash
exec docker compose "$@"
EOF
                chmod +x /usr/local/bin/docker-compose
            fi
            log_info "通过dnf安装docker-compose-plugin成功"
            return 0
        fi

        if dnf install -y docker-compose; then
            log_info "通过dnf安装docker-compose成功"
            return 0
        fi
    else
        yum install -y epel-release 2>/dev/null || true
        if yum install -y docker-compose-plugin; then
            if [[ ! -f /usr/local/bin/docker-compose ]]; then
                cat > /usr/local/bin/docker-compose <<'EOF'
#!/bin/bash
exec docker compose "$@"
EOF
                chmod +x /usr/local/bin/docker-compose
            fi
            log_info "通过yum安装docker-compose-plugin成功"
            return 0
        fi

        if yum install -y docker-compose; then
            log_info "通过yum安装docker-compose成功"
            return 0
        fi
    fi

    log_error "所有安装方法都失败了"
    return 1
}

# 配置Docker镜像加速器
change_docker_mirror() {
    log_purple "配置Docker镜像加速器..."
    
    echo
    log_info "选择配置方式："
    log_info "1) 使用预设的国内镜像源"
    log_info "2) 自定义配置镜像源"
    
    local choice
    read -rp "请选择 [1-2]: " choice
    
    case $choice in
        1)
            mkdir -p /etc/docker

            local mirrors_json
            mirrors_json=$(printf '"%s",' "${DOCKER_MIRRORS[@]}")
            mirrors_json="[${mirrors_json%,}]"

            cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ${mirrors_json},
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "default-ulimits": {
        "nofile": {
            "name": "nofile",
            "hard": 65536,
            "soft": 65536
        }
    }
}
EOF

            log_info "重启Docker服务以应用配置..."
            if systemctl daemon-reload && systemctl restart docker; then
                log_info "Docker镜像加速器配置完成！"
                log_info "当前配置的镜像源："
                for mirror in "${DOCKER_MIRRORS[@]}"; do
                    echo "  - $mirror"
                done
            else
                log_error "Docker服务重启失败"
                return 1
            fi
            ;;
        2)
            configure_custom_docker_mirror
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# 自定义配置Docker镜像源
configure_custom_docker_mirror() {
    log_purple "自定义配置Docker镜像源..."
    
    echo
    log_info "支持的镜像源格式："
    log_info "  - 官方源: https://registry-1.docker.io"
    log_info "  - 国内源: https://registry.docker-cn.com"
    log_info "  - 阿里云: https://<your-id>.mirror.aliyuncs.com"
    log_info "  - 腾讯云: https://mirror.ccs.tencentyun.com"
    
    local custom_mirrors=()
    local mirror_count=0
    
    while true; do
        echo
        read -rp "请输入镜像源地址 (直接回车结束输入): " mirror_url
        
        if [[ -z "$mirror_url" ]]; then
            break
        fi
        
        if [[ ! "$mirror_url" =~ ^https?:// ]]; then
            log_error "无效的URL格式，请输入完整的http或https地址"
            continue
        fi
        
        custom_mirrors+=("$mirror_url")
        mirror_count=$((mirror_count + 1))
        log_info "已添加镜像源: $mirror_url"
    done
    
    if [[ $mirror_count -eq 0 ]]; then
        log_info "未添加任何镜像源，操作取消"
        return 0
    fi
    
    echo
    log_info "将要配置的镜像源："
    for i in "${!custom_mirrors[@]}"; do
        echo "  $((i+1)). ${custom_mirrors[i]}"
    done
    
    if ! confirm_action "确认配置这些镜像源？"; then
        log_info "操作取消"
        return 0
    fi
    
    mkdir -p /etc/docker

    local mirrors_json
    mirrors_json=$(printf '"%s",' "${custom_mirrors[@]}")
    mirrors_json="[${mirrors_json%,}]"

    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ${mirrors_json},
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "default-ulimits": {
        "nofile": {
            "name": "nofile",
            "hard": 65536,
            "soft": 65536
        }
    }
}
EOF

    log_info "重启Docker服务以应用配置..."
    if systemctl daemon-reload && systemctl restart docker; then
        log_info "Docker镜像源配置完成！"
        log_info "当前配置的镜像源："
        for mirror in "${custom_mirrors[@]}"; do
            echo "  - $mirror"
        done
    else
        log_error "Docker服务重启失败"
        return 1
    fi
}

# 显示Docker详细状态
show_docker_status() {
    log_purple "Docker系统状态检查..."

    if ! command_exists docker; then
        log_error "Docker命令不存在，请先安装Docker"
        return 1
    fi

    log_blue "=== Docker服务状态 ==="
    if systemctl is-active docker >/dev/null 2>&1; then
        log_info "Docker服务: 运行中 ✓"
        if docker info >/dev/null 2>&1; then
            log_info "Docker守护进程: 响应正常 ✓"
            systemctl status docker --no-pager -l | head -10 || true

            echo
            log_blue "=== 版本信息 ==="
            local docker_client=$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo "未知")
            local docker_server=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "未知")
            local compose_version="未安装"
            
            if command_exists docker-compose; then
                compose_version=$(docker-compose version --short 2>/dev/null || echo "未知")
            fi
            
            log_info "Docker: $docker_client (客户端) / $docker_server (服务端)"
            log_info "Docker Compose: $compose_version"

            echo
            log_blue "=== 容器状态 ==="
            local running_count stopped_count total_count
            running_count=$(docker ps -q | wc -l)
            stopped_count=$(docker ps -a --filter "status=exited" --format "{{.ID}}" 2>/dev/null | wc -l)
            total_count=$(docker ps -aq | wc -l)

            log_info "运行中容器: $running_count"
            log_info "已停止容器: $stopped_count"
            log_info "总容器数: $total_count"

            if [[ $running_count -gt 0 ]]; then
                echo
                log_info "运行中的容器:"
                docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            fi

            echo
            log_blue "=== 镜像状态 ==="
            local images_count
            images_count=$(docker images -q | wc -l)
            log_info "本地镜像数: $images_count"

            if [[ $images_count -gt 0 ]]; then
                echo
                log_info "镜像列表 (前10个):"
                docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | head -11
            fi

            echo
            log_blue "=== 磁盘使用情况 ==="
            docker system df 2>/dev/null || log_error "无法获取磁盘使用情况"
        else
            log_error "Docker服务正在运行，但守护进程没有响应。"
            log_warn "可能正在启动中，请稍后再试。"
            systemctl status docker --no-pager -l | head -10
        fi
    else
        log_error "Docker服务: 未运行 ✗"
        log_warn "请运行 'sudo systemctl start docker' 启动服务"
    fi
}

# 完全卸载Docker
uninstall_docker() {
    log_purple "Docker完全卸载..."

    log_warn "⚠️  警告：此操作将："
    log_warn "  - 停止并删除所有Docker容器"
    log_warn "  - 删除所有Docker镜像和数据卷"
    log_warn "  - 卸载Docker和Docker Compose"
    log_warn "  - 删除所有Docker相关配置和数据"
    log_warn "  - 这个操作不可逆！"

    echo
    if ! confirm_action "⚠️  确认完全卸载Docker？"; then
        log_info "操作已取消"
        return 0
    fi

    echo
    log_error "最后确认：输入 'YES' 继续卸载，输入其他任何内容取消："
    local final_confirm
    read -rp "> " final_confirm

    if [[ "$(echo "$final_confirm" | tr '[:lower:]' '[:upper:]')" != "YES" ]]; then
        log_info "操作已取消"
        return 0
    fi

    log_info "开始卸载Docker..."

    systemctl stop docker.socket >/dev/null 2>&1 || true
    systemctl stop docker >/dev/null 2>&1 || true
    systemctl disable docker >/dev/null 2>&1 || true

    if command_exists docker; then
        log_info "清理Docker数据..."
        docker system prune -af --volumes >/dev/null 2>&1 || true
    fi

    log_info "卸载Docker软件包..."
    if command_exists dnf; then
        dnf remove -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            docker-compose >/dev/null 2>&1 || true
        dnf autoremove -y >/dev/null 2>&1 || true
    else
        yum remove -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            docker-compose >/dev/null 2>&1 || true
        yum autoremove -y >/dev/null 2>&1 || true
    fi

    log_info "删除Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose

    log_info "删除Docker数据目录..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf /run/docker*
    rm -rf /var/run/docker*

    log_info "清理仓库配置..."
    rm -f /etc/yum.repos.d/docker-ce.repo

    log_info "删除Docker用户组..."
    groupdel docker >/dev/null 2>&1 || true

    log_info "清理残留文件..."
    find /usr/bin /usr/local/bin /sbin /usr/sbin -name "docker*" -type f -delete 2>/dev/null || true

    log_info "Docker卸载完成！"
    log_warn "建议重新登录终端或运行 'hash -r' 清除命令缓存"
}

# 显示主菜单
show_menu() {
    clear
    echo
    echo "================ CentOS Docker 管理脚本 v${SCRIPT_VERSION} ================"
    echo
    echo "📋 Docker 状态管理:"
    echo "  1. 查看 Docker 详细状态"
    echo
    echo "⚙️ 安装配置:"
    echo "  2. 换国内源(yum/dnf)"
    echo "  3. 一键安装 Docker"
    echo "  4. 安装 Docker Compose"
    echo "  5. 配置 Docker 镜像加速器"
    echo
    echo "🗑️ 卸载:"
    echo "  6. 完全卸载 Docker"
    echo
    echo "  0. 退出脚本"
    echo "=================================================="
    echo
}

# 主程序入口
main() {
    log_info "CentOS Docker管理脚本 v${SCRIPT_VERSION} 启动"
    log_info "当前用户: $(whoami)"
    log_info "系统信息: $(uname -sr)"

    while true; do
        show_menu

        local choice
        read -rp "请选择操作 [0-6]: " choice

        echo
        case $choice in
            1) show_docker_status ;;
            2) change_yum_source ;;
            3) install_docker ;;
            4) install_docker_compose ;;
            5) change_docker_mirror ;;
            6) uninstall_docker ;;
            0)
                log_info "感谢使用CentOS Docker管理脚本，再见！"
                exit 0
                ;;
            *)
                log_error "无效选择，请输入 0-6 之间的数字"
                ;;
        esac

        echo
        log_info "操作完成，按任意键返回主菜单..."
        read -r
    done
}

# 捕获中断信号，优雅退出
trap 'log_warn "脚本被中断"; exit 130' INT TERM

# 启动主程序
main "$@"