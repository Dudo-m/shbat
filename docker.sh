#!/bin/bash

# Docker管理脚本 - 优化版
# 作者: Docker管理助手
# 版本: ${SCRIPT_VERSION}
# 描述: 一键式Docker环境管理工具，支持安装、配置、镜像管理等功能

#set -euo pipefail  # 严格模式：遇到错误立即退出
set -uo pipefail

# ==================== 全局变量和配置 ====================

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# 脚本版本
readonly SCRIPT_VERSION="4.1.1"

# 脚本启动时的目录
readonly SCRIPT_START_DIR="$(pwd)"

# Docker Compose稳定版本（当GitHub API不可用时的备用版本）
readonly COMPOSE_FALLBACK_VERSION="v2.24.6"

# 国内可用的Docker镜像源（定期更新维护）
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

# ==================== 日志和工具函数 ====================

# 统一日志输出函数
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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检测操作系统类型
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        log_error "无法检测操作系统类型"
        return 1
    fi
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

# ==================== 系统包管理器换源 ====================

# 更新apt源为国内镜像（适用于Ubuntu/Debian）
change_apt_source() {
    log_purple "配置apt国内镜像源..."

    if ! command_exists apt-get; then
        log_error "当前系统不支持apt包管理器"
        return 1
    fi

    # 备份原有源列表
    local backup_file="/etc/apt/sources.list.bak.$(date +%s)"
    cp /etc/apt/sources.list "$backup_file"
    log_info "已备份原sources.list到: $backup_file"

    # 获取操作系统ID和代号
    local os_id codename
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_id="$ID"
        codename="$VERSION_CODENAME"
    else
        log_error "无法读取 /etc/os-release，无法确定发行版"
        return 1
    fi

    log_info "检测到发行版: $os_id, 代号: $codename"

    # 根据不同发行版写入不同的镜像源
    if [[ "$os_id" == "ubuntu" ]]; then
        log_info "配置Ubuntu镜像源..."
        cat > /etc/apt/sources.list <<EOF
# 阿里云Ubuntu镜像源 - 自动生成于$(date)
deb https://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
EOF
    elif [[ "$os_id" == "debian" ]]; then
        log_info "配置Debian镜像源..."
        cat > /etc/apt/sources.list <<EOF
# 阿里云Debian镜像源 - 自动生成于$(date)
deb https://mirrors.aliyun.com/debian/ $codename main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ $codename-updates main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ $codename-backports main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian-security/ $codename-security main contrib non-free non-free-firmware
EOF
    else
        log_error "不支持的基于apt的发行版: $os_id"
        mv "$backup_file" /etc/apt/sources.list # 恢复备份
        return 1
    fi

    log_info "更新软件包列表..."
    if apt-get update; then
        log_info "apt源配置完成！"
    else
        log_error "apt源更新失败，恢复原配置"
        mv "$backup_file" /etc/apt/sources.list
        apt-get update # 尝试用旧配置刷新
        return 1
    fi
}

# 更新yum源为国内镜像（适用于CentOS/RHEL）
change_yum_source() {
    log_purple "配置yum国内镜像源..."

    if ! command_exists yum && ! command_exists dnf; then
        log_error "当前系统不支持yum/dnf包管理器"
        return 1
    fi

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

[centosplus]
name=CentOS-\$releasever - Plus - mirrors.aliyun.com
failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
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

# ==================== Docker安装相关函数 ====================

# 安装系统依赖
install_dependencies() {
    log_purple "安装系统依赖包..."

    if command_exists apt-get;
        then
        apt-get update
        
        local os_id
        os_id=$(detect_os)
        
        # 定义基础依赖包
        local packages_to_install=(
            "apt-transport-https"
            "ca-certificates"
            "curl"
            "gnupg"
            "lsb-release"
            "wget"
        )
        
        # software-properties-common 主要用于Ubuntu管理PPA，Debian通常不需要
        if [[ "$os_id" == "ubuntu" ]]; then
            packages_to_install+=("software-properties-common")
        fi
        
        log_info "将为 $os_id 安装以下依赖: ${packages_to_install[*]}"
        if ! apt-get install -y "${packages_to_install[@]}"; then
            log_error "依赖包安装失败"
            return 1
        fi

    elif command_exists yum;
        then
        yum install -y \
            yum-utils \
            device-mapper-persistent-data \
            lvm2 \
            curl \
            wget
    elif command_exists dnf;
        then
        dnf install -y \
            dnf-utils \
            device-mapper-persistent-data \
            lvm2 \
            curl \
            wget
    else
        log_error "不支持的包管理器"
        return 1
    fi
}


# Docker安装（合并国内外源）
install_docker() {
    log_purple "开始安装Docker..."

    if command_exists docker; then
        log_warn "Docker已安装，版本信息："
        docker --version
        return 0
    fi

    # 询问用户选择源
    local source_choice
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
            install_docker_cn_impl
            ;;
        *)
            log_info "使用官方源安装Docker..."
            install_docker_official_impl
            ;;
    esac
}

# Docker官方源安装实现
install_docker_official_impl() {
    check_network
    install_dependencies

    local os_type
    os_type=$(detect_os)
    log_info "检测到操作系统: $os_type"

    if [[ "$os_type" =~ ^(ubuntu|debian)$ ]]; then
        # Ubuntu/Debian安装流程
        curl -fsSL https://download.docker.com/linux/$os_type/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$os_type $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

    elif [[ "$os_type" =~ ^(centos|rhel|fedora)$ ]]; then
        # CentOS/RHEL/Fedora安装流程
        if command_exists dnf; then
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
        else
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
        fi
    else
        log_error "不支持的操作系统: $os_type"
        return 1
    fi

    # 启动并设置开机自启
    systemctl start docker
    systemctl enable docker

    # 添加当前用户到docker组
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "已将用户 $SUDO_USER 添加到docker组，请重新登录生效"
    fi

    log_info "Docker安装完成！"
    docker --version
}

# Docker国内源安装实现
install_docker_cn_impl() {
    check_network
    install_dependencies

    local os_type
    os_type=$(detect_os)
    log_info "检测到操作系统: $os_type"

    if [[ "$os_type" =~ ^(ubuntu|debian)$ ]]; then
        # 使用阿里云Docker源
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$os_type/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/$os_type $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

    elif [[ "$os_type" =~ ^(centos|rhel|fedora)$ ]]; then
        # 使用阿里云Docker源
        if command_exists dnf; then
            dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
        else
            yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
        fi
    else
        log_error "不支持的操作系统: $os_type"
        return 1
    fi

    # 启动并设置开机自启
    systemctl start docker
    systemctl enable docker

    # 添加当前用户到docker组
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

    # 尝试从GitHub API获取最新版本
    version=$(curl -s --connect-timeout 10 --max-time 15 \
        "https://api.github.com/repos/docker/compose/releases/latest" 2>/dev/null | \
        grep -o '"tag_name": *"[^"]*"' | \
        grep -o '[^"]*$' | \
        head -1)

    # 如果GitHub API失败，使用备用版本
    if [[ -z "$version" ]]; then
        log_warn "无法获取最新版本，使用备用版本: $COMPOSE_FALLBACK_VERSION"
        version="$COMPOSE_FALLBACK_VERSION"
    else
        log_info "获取到最新版本: $version"
    fi

    echo "$version"
}

# Docker Compose安装（合并国内外源）
install_docker_compose() {
    log_purple "开始安装Docker Compose..."

    if command_exists docker-compose; then
        log_warn "Docker Compose已安装，版本信息："
        docker-compose --version
        return 0
    fi

    # 询问用户选择源
    local source_choice
    echo
    log_info "请选择Docker Compose安装源："
    log_info "  1) 官方源（默认）"
    log_info "  2) 国内源（推荐国内用户选择）"
    echo
    read -rp "请输入选择 (1/2，默认为1): " source_choice
    echo

    case "${source_choice:-1}" in
        2)
            log_info "使用国内源安装Docker Compose..."
            install_docker_compose_cn_impl
            ;;
        *)
            log_info "使用官方源安装Docker Compose..."
            install_docker_compose_official_impl
            ;;
    esac
}

# Docker Compose官方源安装实现
install_docker_compose_official_impl() {
    check_network

    local version
    version=$(get_latest_compose_version)

    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    # 适配不同架构
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

# Docker Compose国内源安装实现
install_docker_compose_cn_impl() {
    check_network

    # 方法1：通过包管理器安装（推荐，稳定性最好）
    if install_compose_via_package_manager; then
        return 0
    fi

    # 方法2：通过国内镜像源下载二进制文件
    if install_compose_via_mirror; then
        return 0
    fi

    # 方法3：通过pip安装（备用方案）
    if install_compose_via_pip; then
        return 0
    fi

    log_error "所有安装方法都失败了"
    return 1
}

# 通过包管理器安装Docker Compose
install_compose_via_package_manager() {
    log_info "尝试通过系统包管理器安装..."

    if command_exists apt-get; then
        # Ubuntu/Debian：先尝试安装docker-compose-plugin
        if apt-get update && apt-get install -y docker-compose-plugin; then
            # 创建docker-compose命令的软链接以兼容旧版本使用习惯
            if [[ ! -f /usr/local/bin/docker-compose ]]; then
                cat > /usr/local/bin/docker-compose <<'EOF'
#!/bin/bash
exec docker compose "$@"
EOF
                chmod +x /usr/local/bin/docker-compose
            fi
            log_info "通过apt安装docker-compose-plugin成功"
            return 0
        fi

        # 如果plugin安装失败，尝试传统的docker-compose包
        if apt-get install -y docker-compose; then
            log_info "通过apt安装docker-compose成功"
            return 0
        fi

    elif command_exists yum; then
        # CentOS/RHEL：尝试通过EPEL源安装
        yum install -y epel-release 2>/dev/null || true
        if yum install -y docker-compose; then
            log_info "通过yum安装docker-compose成功"
            return 0
        fi

    elif command_exists dnf; then
        # Fedora：通过dnf安装
        if dnf install -y docker-compose; then
            log_info "通过dnf安装docker-compose成功"
            return 0
        fi
    fi

    log_warn "包管理器安装失败，尝试其他方法..."
    return 1
}

# 通过国内镜像源下载安装Docker Compose
install_compose_via_mirror() {
    log_info "尝试通过国内镜像源下载安装..."

    local version
    version=$(get_latest_compose_version)

    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    # 架构适配
    case $arch in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        armv7l) arch="armv7" ;;
        *) log_error "不支持的架构: $arch"; return 1 ;;
    esac

    # 国内镜像源列表（按可靠性排序）
    local mirrors=(
        "https://get.daocloud.io/docker/compose/releases/download"
        "https://github.91chi.fun/https://github.com/docker/compose/releases/download"
        "https://hub.fastgit.xyz/docker/compose/releases/download"
        "https://download.fastgit.org/docker/compose/releases/download"
    )

    local filename="docker-compose-${os}-${arch}"

    for mirror in "${mirrors[@]}"; do
        local download_url="${mirror}/${version}/${filename}"
        log_info "尝试从 ${mirror} 下载..."

        if curl -L --fail --connect-timeout 15 --max-time 120 \
            --progress-bar "$download_url" -o /usr/local/bin/docker-compose; then
            chmod +x /usr/local/bin/docker-compose

            # 验证安装
            if /usr/local/bin/docker-compose --version >/dev/null 2>&1; then
                log_info "Docker Compose安装成功！"
                docker-compose --version
                return 0
            else
                log_warn "下载的文件无效，删除并尝试下一个源..."
                rm -f /usr/local/bin/docker-compose
            fi
        else
            log_warn "从 ${mirror} 下载失败"
        fi
    done

    log_warn "所有镜像源下载都失败"
    return 1
}

# 通过pip安装Docker Compose（备用方案）
install_compose_via_pip() {
    log_info "尝试通过pip安装（备用方案）..."

    # 检查或安装pip
    if ! command_exists pip3 && ! command_exists pip; then
        log_info "安装pip..."
        if command_exists apt-get; then
            apt-get install -y python3-pip
        elif command_exists yum; then
            yum install -y python3-pip
        elif command_exists dnf; then
            dnf install -y python3-pip
        else
            log_warn "无法安装pip，跳过此方法"
            return 1
        fi
    fi

    # 使用国内pip源安装
    local pip_cmd
    pip_cmd=$(command -v pip3 || command -v pip)

    if [[ -n "$pip_cmd" ]]; then
        log_info "通过pip安装docker-compose..."
        if "$pip_cmd" install docker-compose -i https://pypi.tuna.tsinghua.edu.cn/simple; then
            log_info "通过pip安装docker-compose成功"
            docker-compose --version
            return 0
        fi
    fi

    log_warn "pip安装失败"
    return 1
}

# ==================== Docker配置相关函数 ====================

# 配置Docker镜像加速器
# 自定义配置Docker镜像源（简化版）
configure_custom_docker_mirror() {
    log_purple "自定义配置Docker镜像源..."
    
    echo
    log_info "支持的镜像源格式："
    log_info "  - 官方源: https://registry-1.docker.io"
    log_info "  - 国内源: https://registry.docker-cn.com"
    log_info "  - 阿里云: https://<your-id>.mirror.aliyuncs.com"
    log_info "  - 腾讯云: https://mirror.ccs.tencentyun.com"
    log_info "  - 华为云: https://<your-id>.mirror.swr.myhuaweicloud.com"
    log_info "  - 七牛云: https://reg-mirror.qiniu.com"
    log_info "  - 网易: https://hub-mirror.c.163.com"
    log_info "  - 中科大: https://docker.mirrors.ustc.edu.cn"
    
    local custom_mirrors=()
    local mirror_count=0
    
    while true; do
        echo
        read -rp "请输入镜像源地址 (直接回车结束输入): " mirror_url
        
        if [[ -z "$mirror_url" ]]; then
            break
        fi
        
        # 验证URL格式
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
    
    # 创建docker配置目录
    mkdir -p /etc/docker

    # 直接替换配置文件（不备份）
    local mirrors_json
    mirrors_json=$(printf '"%s",' "${custom_mirrors[@]}")
    mirrors_json="[${mirrors_json%,}]"

    # 写入配置文件
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

    # 重启Docker服务
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

# 预设镜像源配置（保留原有功能）
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
            # 创建docker配置目录
            mkdir -p /etc/docker

            # 直接替换配置文件（不备份）
            local mirrors_json
            mirrors_json=$(printf '"%s",' "${DOCKER_MIRRORS[@]}")
            mirrors_json="[${mirrors_json%,}]"

            # 写入配置文件
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

            # 重启Docker服务
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

# ==================== 容器管理相关函数 ====================

# 交互式选择并停止运行中的容器
stop_selected_containers() {
    log_purple "交互式选择停止运行中的容器..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    local running_containers
    running_containers=$(docker ps --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null | grep -E "Up\|running" || true)

    if [[ -z "$running_containers" ]]; then
        log_warn "没有运行中的容器"
        return 0
    fi

    # 显示运行中的容器列表
    log_blue "=== 运行中的容器列表 ==="
    local container_array=()
    local i=1
    
    while IFS='|' read -r id name image status; do
        container_array[i]="$id|$name|$image|$status"
        printf "%-3s %-20s %-30s %s\n" "$i" "$name" "$image" "$status"
        i=$((i + 1))
    done <<< "$running_containers"
    log_blue "========================"

    echo
    log_info "选择方式："
    log_info "  输入容器编号（空格分隔多个），例如: 1 3 5"
    log_info "  输入 'all' 停止所有容器"
    log_info "  输入 'q' 或直接回车退出"

    local selection
    read -rp "> " selection

    if [[ -z "$selection" || "$selection" == "q" ]]; then
        log_info "操作已取消"
        return 0
    fi

    local selected_containers=""
    if [[ "$selection" == "all" ]]; then
        selected_containers=$(echo "$running_containers" | cut -d'|' -f1)
    else
        # 解析用户输入的编号
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]]; then
                local container_info
                container_info=$(echo "$running_containers" | sed -n "${num}p")
                if [[ -n "$container_info" ]]; then
                    local container_id=$(echo "$container_info" | cut -d'|' -f1)
                    local container_name=$(echo "$container_info" | cut -d'|' -f2)
                    selected_containers+="$container_id\n"
                else
                    log_warn "无效编号: $num"
                fi
            else
                log_warn "无效输入: $num"
            fi
        done
        selected_containers=$(echo -e "$selected_containers" | sed '/^$/d')
    fi

    if [[ -z "$selected_containers" ]]; then
        log_error "没有有效的容器被选中"
        return 1
    fi

    # 显示选中的容器
    local selected_count
    selected_count=$(echo "$selected_containers" | wc -l)
    log_info "已选择 $selected_count 个容器:"
    
    local container_ids=($selected_containers)
    for container_id in "${container_ids[@]}"; do
        local container_info
        container_info=$(docker ps --format "{{.ID}}|{{.Names}}|{{.Image}}" --filter "id=$container_id" 2>/dev/null)
        if [[ -n "$container_info" ]]; then
            local name=$(echo "$container_info" | cut -d'|' -f2)
            echo "  - $name ($container_id)"
        fi
    done

    echo
    if ! confirm_action "确认停止这些容器？"; then
        log_info "操作已取消"
        return 0
    fi

    # 开始停止容器
    local current=0
    local success_count=0
    local fail_count=0

    for container_id in "${container_ids[@]}"; do
        [[ -z "$container_id" ]] && continue
        current=$((current + 1))

        local container_name
        container_name=$(docker ps --format "{{.Names}}" --filter "id=$container_id" 2>/dev/null || echo "$container_id")

        log_info "[$current/$selected_count] 正在停止: $container_name"

        if docker stop "$container_id" >/dev/null 2>&1; then
            log_info "✓ 停止成功: $container_name"
            success_count=$((success_count + 1))
        else
            log_error "✗ 停止失败: $container_name"
            fail_count=$((fail_count + 1))
        fi
    done

    echo
    log_info "=== 停止完成统计 ==="
    log_info "总容器数: $selected_count"
    log_info "成功: $success_count"
    [[ $fail_count -gt 0 ]] && log_warn "失败: $fail_count"
}

# 交互式选择并删除容器
remove_selected_containers() {
    log_purple "交互式选择删除容器..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    local all_containers
    all_containers=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)

    if [[ -z "$all_containers" ]]; then
        log_warn "没有容器需要删除"
        return 0
    fi

    # 显示所有容器列表
    log_blue "=== 所有容器列表 ==="
    local container_array=()
    local i=1
    
    while IFS='|' read -r id name image status; do
        container_array[i]="$id|$name|$image|$status"
        printf "%-3s %-20s %-30s %s\n" "$i" "$name" "$image" "$status"
        i=$((i + 1))
    done <<< "$all_containers"
    log_blue "========================"

    echo
    log_info "选择方式："
    log_info "  输入容器编号（空格分隔多个），例如: 1 3 5"
    log_info "  输入 'all' 删除所有容器"
    log_info "  输入 'q' 或直接回车退出"

    local selection
    read -rp "> " selection

    if [[ -z "$selection" || "$selection" == "q" ]]; then
        log_info "操作已取消"
        return 0
    fi

    local selected_containers=""
    if [[ "$selection" == "all" ]]; then
        selected_containers=$(echo "$all_containers" | cut -d'|' -f1)
    else
        # 解析用户输入的编号
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]]; then
                local container_info
                container_info=$(echo "$all_containers" | sed -n "${num}p")
                if [[ -n "$container_info" ]]; then
                    local container_id=$(echo "$container_info" | cut -d'|' -f1)
                    selected_containers+="$container_id\n"
                else
                    log_warn "无效编号: $num"
                fi
            else
                log_warn "无效输入: $num"
            fi
        done
        selected_containers=$(echo -e "$selected_containers" | sed '/^$/d')
    fi

    if [[ -z "$selected_containers" ]]; then
        log_error "没有有效的容器被选中"
        return 1
    fi

    # 显示选中的容器
    local selected_count
    selected_count=$(echo "$selected_containers" | wc -l)
    log_info "已选择 $selected_count 个容器:"
    
    local container_ids=($selected_containers)
    for container_id in "${container_ids[@]}"; do
        local container_info
        container_info=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}" --filter "id=$container_id" 2>/dev/null)
        if [[ -n "$container_info" ]]; then
            local name=$(echo "$container_info" | cut -d'|' -f2)
            echo "  - $name ($container_id)"
        fi
    done

    echo
    if ! confirm_action "⚠️  这将删除选中的容器，包括其中的数据！确认继续？"; then
        log_info "操作已取消"
        return 0
    fi

    # 开始删除容器
    local current=0
    local success_count=0
    local fail_count=0

    for container_id in "${container_ids[@]}"; do
        [[ -z "$container_id" ]] && continue
        current=$((current + 1))

        local container_name
        container_name=$(docker ps -a --format "{{.Names}}" --filter "id=$container_id" 2>/dev/null || echo "$container_id")

        log_info "[$current/$selected_count] 正在删除: $container_name"

        # 先停止容器（如果是运行中的）
        if docker ps --filter "id=$container_id" --format "{{.ID}}" | grep -q "$container_id"; then
            log_info "  正在停止运行中的容器: $container_name"
            docker stop "$container_id" >/dev/null 2>&1 || true
        fi

        if docker rm "$container_id" >/dev/null 2>&1; then
            log_info "✓ 删除成功: $container_name"
            success_count=$((success_count + 1))
        else
            log_error "✗ 删除失败: $container_name"
            fail_count=$((fail_count + 1))
        fi
    done

    echo
    log_info "=== 删除完成统计 ==="
    log_info "总容器数: $selected_count"
    log_info "成功: $success_count"
    [[ $fail_count -gt 0 ]] && log_warn "失败: $fail_count"
}

# 交互式选择并启动已停止的容器
start_selected_containers() {
    log_purple "交互式选择启动已停止的容器..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    local stopped_containers
    stopped_containers=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null | grep -E "(Exited|Created)" || true)

    if [[ -z "$stopped_containers" ]]; then
        log_warn "没有已停止的容器需要启动"
        return 0
    fi

    # 显示已停止的容器列表
    log_blue "=== 已停止的容器列表 ==="
    local container_array=()
    local i=1
    
    while IFS='|' read -r id name image status; do
        container_array[i]="$id|$name|$image|$status"
        printf "%-3s %-20s %-30s %s\n" "$i" "$name" "$image" "$status"
        i=$((i + 1))
    done <<< "$stopped_containers"
    log_blue "========================"

    echo
    log_info "选择方式："
    log_info "  输入容器编号（空格分隔多个），例如: 1 3 5"
    log_info "  输入 'all' 启动所有已停止的容器"
    log_info "  输入 'q' 或直接回车退出"

    local selection
    read -rp "> " selection

    if [[ -z "$selection" || "$selection" == "q" ]]; then
        log_info "操作已取消"
        return 0
    fi

    local selected_containers=""
    if [[ "$selection" == "all" ]]; then
        selected_containers=$(echo "$stopped_containers" | cut -d'|' -f1)
    else
        # 解析用户输入的编号
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]]; then
                local container_info
                container_info=$(echo "$stopped_containers" | sed -n "${num}p")
                if [[ -n "$container_info" ]]; then
                    local container_id=$(echo "$container_info" | cut -d'|' -f1)
                    selected_containers+="$container_id\n"
                else
                    log_warn "无效编号: $num"
                fi
            else
                log_warn "无效输入: $num"
            fi
        done
        selected_containers=$(echo -e "$selected_containers" | sed '/^$/d')
    fi

    if [[ -z "$selected_containers" ]]; then
        log_error "没有有效的容器被选中"
        return 1
    fi

    # 显示选中的容器
    local selected_count
    selected_count=$(echo "$selected_containers" | wc -l)
    log_info "已选择 $selected_count 个容器:"
    
    local container_ids=($selected_containers)
    for container_id in "${container_ids[@]}"; do
        local container_info
        container_info=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}" --filter "id=$container_id" 2>/dev/null)
        if [[ -n "$container_info" ]]; then
            local name=$(echo "$container_info" | cut -d'|' -f2)
            echo "  - $name ($container_id)"
        fi
    done

    echo
    if ! confirm_action "确认启动这些容器？"; then
        log_info "操作已取消"
        return 0
    fi

    # 开始启动容器
    local current=0
    local success_count=0
    local fail_count=0

    for container_id in "${container_ids[@]}"; do
        [[ -z "$container_id" ]] && continue
        current=$((current + 1))

        local container_name
        container_name=$(docker ps -a --format "{{.Names}}" --filter "id=$container_id" 2>/dev/null || echo "$container_id")

        log_info "[$current/$selected_count] 正在启动: $container_name"

        if docker start "$container_id" >/dev/null 2>&1; then
            log_info "✓ 启动成功: $container_name"
            success_count=$((success_count + 1))
        else
            log_error "✗ 启动失败: $container_name"
            fail_count=$((fail_count + 1))
        fi
    done

    echo
    log_info "=== 启动完成统计 ==="
    log_info "总容器数: $selected_count"
    log_info "成功: $success_count"
    [[ $fail_count -gt 0 ]] && log_warn "失败: $fail_count"
}

# ==================== 镜像管理相关函数 ====================

# 创建通用的镜像导入脚本
create_import_script() {
    local export_dir="$1"
    local import_script="$export_dir/import_images.sh"

    cat > "$import_script" <<'EOF'
#!/bin/bash
# Docker镜像导入脚本 (自动生成)
# 使用方法: ./import_images.sh

set -euo pipefail

# 颜色定义
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"; }

main() {
    # 检查Docker是否安装
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi

    # 检查Docker服务是否运行
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker服务未运行，请启动Docker服务"
        exit 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    log_info "开始导入Docker镜像..."
    log_info "扫描目录: $script_dir"

    # 查找所有tar文件
    local tar_files
    tar_files=$(find "$script_dir" -maxdepth 1 -name "*.tar" -type f)

    if [[ -z "$tar_files" ]]; then
        log_error "在目录中未找到任何 .tar 镜像文件"
        exit 1
    fi

    local total_files
    total_files=$(echo "$tar_files" | wc -l)
    local current=0
    local success_count=0
    local fail_count=0

    log_info "找到 $total_files 个镜像文件"

    while IFS= read -r tar_file; do
        current=$((current + 1))
        local filename
        filename=$(basename "$tar_file")

        log_info "[$current/$total_files] 正在导入: $filename"

        if docker load -i "$tar_file"; then
            log_info "✓ 导入成功: $filename"
            success_count=$((success_count + 1))
        else
            log_error "✗ 导入失败: $filename"
            fail_count=$((fail_count + 1))
        fi
    done <<< "$tar_files"

    echo
    log_info "=== 导入完成统计 ==="
    log_info "总文件数: $total_files"
    log_info "成功: $success_count"
    [[ $fail_count -gt 0 ]] && log_warn "失败: $fail_count"

    if [[ $success_count -gt 0 ]]; then
        echo
        log_info "当前系统镜像列表："
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
    fi
}

main "$@"
EOF

    chmod +x "$import_script"
    log_info "已创建导入脚本: $import_script"
}

# 交互式选择镜像导出
export_selected_images() {
    log_purple "交互式选择镜像导出..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    local image_list
    image_list=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")

    if [[ -z "$image_list" ]]; then
        log_warn "没有可用的镜像"
        return 0
    fi

    # 显示镜像列表
    log_blue "=== 本地镜像列表 ==="
    local i=1
    while IFS= read -r image; do
        local size
        size=$(docker images --format "{{.Size}}" "$image" 2>/dev/null || echo "unknown")
        printf "%-4s %-50s %s\n" "$i" "$image" "$size"
        i=$((i + 1))
    done <<< "$image_list"
    log_blue "========================"

    echo
    log_info "选择方式："
    log_info "  输入镜像编号（空格分隔多个），例如: 1 3 5"
    log_info "  输入 'all' 导出所有镜像"
    log_info "  输入 'q' 或直接回车退出"

    local selection
    read -rp "请输入选择: " selection

    if [[ -z "$selection" || "$selection" == "q" ]]; then
        log_info "操作已取消"
        return 0
    fi

    local selected_images=""
    if [[ "$selection" == "all" ]]; then
        selected_images="$image_list"
    else
        # 解析用户输入的编号
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]]; then
                local image
                image=$(echo "$image_list" | sed -n "${num}p")
                if [[ -n "$image" ]]; then
                    selected_images+="$image\n"
                else
                    log_warn "无效编号: $num"
                fi
            else
                log_warn "无效输入: $num"
            fi
        done
        selected_images=$(echo -e "$selected_images" | sed '/^$/d')
    fi

    if [[ -z "$selected_images" ]]; then
        log_error "没有有效的镜像被选中"
        return 1
    fi

    # 显示选中的镜像
    local selected_count
    selected_count=$(echo "$selected_images" | wc -l)
    log_info "已选择 $selected_count 个镜像:"
    echo "$selected_images" | while IFS= read -r image; do
        echo "  - $image"
    done

    echo
    if ! confirm_action "确认导出这些镜像？"; then
        log_info "操作已取消"
        return 0
    fi

    # 开始导出
    local export_dir="./docker_images_selected_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    log_info "镜像将导出到: $export_dir"

    create_import_script "$export_dir"

    local current=0
    local success_count=0
    local fail_count=0

    while IFS= read -r image; do
        [[ -z "$image" ]] && continue
        current=$((current + 1))

        local safe_name
        safe_name=$(echo "$image" | sed 's|[/:@]|_|g')
        local tar_file="$export_dir/${safe_name}.tar"

        log_info "[$current/$selected_count] 正在导出: $image"

        if docker save -o "$tar_file" "$image"; then
            log_info "✓ 导出成功: $(basename "$tar_file")"
            success_count=$((success_count + 1))
        else
            log_error "✗ 导出失败: $image"
            fail_count=$((fail_count + 1))
            rm -f "$tar_file"
        fi
    done <<< "$selected_images"

    echo
    log_info "=== 导出完成统计 ==="
    log_info "选中镜像数: $selected_count"
    log_info "成功: $success_count"
    [[ $fail_count -gt 0 ]] && log_warn "失败: $fail_count"

    if [[ $success_count -gt 0 ]]; then
        local export_size
        export_size=$(du -sh "$export_dir" | cut -f1)
        log_info "导出目录大小: $export_size"
        log_info "要导入这些镜像，请将目录拷贝到目标机器并运行:"
        log_info "cd $(basename "$export_dir") && ./import_images.sh"
    fi
}

# 从指定目录导入镜像
import_images_from_dir() {
    log_purple "从指定目录导入镜像..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    local import_dir
    read -rp "请输入包含 .tar 镜像文件的目录路径: " import_dir

    if [[ -z "$import_dir" ]]; then
        log_error "目录路径不能为空"
        return 1
    fi

    # 支持相对路径和绝对路径
    import_dir=$(realpath "$import_dir" 2>/dev/null) || {
        log_error "无效的目录路径: $import_dir"
        return 1
    }

    if [[ ! -d "$import_dir" ]]; then
        log_error "目录不存在: $import_dir"
        return 1
    fi

    log_info "扫描目录: $import_dir"

    local tar_files
    tar_files=$(find "$import_dir" -maxdepth 1 -name "*.tar" -type f)

    if [[ -z "$tar_files" ]]; then
        log_warn "在目录中未找到 .tar 文件"
        return 0
    fi

    local total_files
    total_files=$(echo "$tar_files" | wc -l)
    log_info "找到 $total_files 个镜像文件"

    if ! confirm_action "确认导入这些镜像？"; then
        log_info "操作已取消"
        return 0
    fi

    local current=0
    local success_count=0
    local fail_count=0

    while IFS= read -r tar_file; do
        current=$((current + 1))
        local filename
        filename=$(basename "$tar_file")

        log_info "[$current/$total_files] 正在导入: $filename"

        if docker load -i "$tar_file"; then
            log_info "✓ 导入成功: $filename"
            success_count=$((success_count + 1))
        else
            log_error "✗ 导入失败: $filename"
            fail_count=$((fail_count + 1))
        fi
    done <<< "$tar_files"

    echo
    log_info "=== 导入完成统计 ==="
    log_info "总文件数: $total_files"
    log_info "成功: $success_count"
    [[ $fail_count -gt 0 ]] && log_warn "失败: $fail_count"

    if [[ $success_count -gt 0 ]]; then
        log_info "镜像导入完成，当前镜像列表："
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
    fi
}

# ==================== 系统清理相关函数 ====================

# 清理Docker系统
clean_docker_system() {
    log_purple "Docker系统清理..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    # 显示清理前的状态
    log_info "清理前的磁盘使用情况："
    docker system df

    echo
    log_warn "清理操作包括："
    log_warn "  - 删除所有未使用的容器"
    log_warn "  - 删除所有未使用的网络"
    log_warn "  - 删除所有未使用的镜像（包括悬挂镜像）"
    log_warn "  - 删除所有未使用的数据卷"
    log_warn "  - 删除所有构建缓存"

    echo
    if ! confirm_action "⚠️  这将删除所有未使用的Docker资源！确认继续？"; then
        log_info "操作已取消"
        return 0
    fi

    log_info "开始清理Docker系统..."

    if docker system prune -af --volumes; then
        echo
        log_info "清理完成！清理后的磁盘使用情况："
        docker system df
    else
        log_error "Docker系统清理失败"
        return 1
    fi
}

# ==================== Docker状态和信息相关函数 ====================

# 查看容器日志（交互式选择容器）
view_container_logs() {
    log_purple "查看容器日志..."

    if ! command_exists docker; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    # 获取所有容器列表（包括运行中和已停止的）
    local containers
    containers=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        log_warn "没有找到任何容器"
        return 0
    fi

    # 显示容器列表
    log_blue "=== 容器列表 ==="
    local container_array=()
    local i=1
    
    while IFS='|' read -r id name image status; do
        container_array[i]="$id|$name|$image|$status"
        printf "%-3s %-20s %-30s %s\n" "$i" "$name" "$image" "$status"
        i=$((i + 1))
    done <<< "$containers"

    echo
    log_info "请选择要查看日志的容器（输入编号，按回车确认，q退出）:"
    
    local selected_index
    while true; do
        read -rp "> " selected_index
        
        # 检查是否退出
        if [[ "$selected_index" == "q" || "$selected_index" == "Q" || -z "$selected_index" ]]; then
            log_info "已取消操作"
            return 0
        fi
        
        # 验证输入是否为有效数字
        if [[ "$selected_index" =~ ^[0-9]+$ ]] && [[ "$selected_index" -ge 1 ]] && [[ "$selected_index" -lt "$i" ]]; then
            break
        else
            log_error "无效的选择，请输入 1-$((i-1)) 之间的数字"
        fi
    done

    # 获取选中的容器信息
    local selected_container="${container_array[selected_index]}"
    local container_id=$(echo "$selected_container" | cut -d'|' -f1)
    local container_name=$(echo "$selected_container" | cut -d'|' -f2)

    log_info "正在查看容器 '$container_name' 的日志..."
    log_info "使用命令: docker logs -f --tail 100 $container_name"
    echo
    
    # 使用docker logs查看日志
    docker logs -f --tail 100 "$container_name"
}

# 显示Docker详细状态
show_docker_status() {
    log_purple "Docker系统状态检查..."

    # 检查Docker命令可用性
    if ! command_exists docker; then
        log_error "Docker命令不存在，请先安装Docker"
        return 1
    fi

    # 检查Docker服务状态
    log_blue "=== Docker服务状态 ==="
    if systemctl is-active docker >/dev/null 2>&1; then
        log_info "Docker服务: 运行中 ✓"
        # 进一步检查Docker守护进程是否响应
        if docker info >/dev/null 2>&1; then
            log_info "Docker守护进程: 响应正常 ✓"
            systemctl status docker --no-pager -l | head -10 || true

            # 版本信息
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

            # 容器状态
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

            if [[ $stopped_count -gt 0 ]]; then
                echo
                log_info "已停止的容器:"
                docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || true
            fi

            # 镜像状态
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

            # 磁盘使用情况
            echo
            log_blue "=== 磁盘使用情况 ==="
            docker system df 2>/dev/null || log_error "无法获取磁盘使用情况"

            # Docker配置检查
            echo
            log_blue "=== Docker配置检查 ==="
            if [[ -f /etc/docker/daemon.json ]]; then
                log_info "发现Docker配置文件: /etc/docker/daemon.json"
                
                # 显示已配置的镜像源
                if command_exists jq; then
                    local mirrors=$(jq -r '.["registry-mirrors"] | join(", ")' /etc/docker/daemon.json 2>/dev/null || echo "")
                    if [[ -n "$mirrors" && "$mirrors" != "null" ]]; then
                        log_info "已配置的镜像源："
                        IFS=', ' read -ra MIRROR_ARRAY <<< "$mirrors"
                        for mirror in "${MIRROR_ARRAY[@]}"; do
                            echo "  - $mirror"
                        done
                    else
                        log_warn "镜像源: 未配置"
                    fi
                else
                    # 如果没有jq，使用grep和sed提取
                    local mirrors_raw=$(grep -E '"registry-mirters"|"registry-mirrors"' /etc/docker/daemon.json 2>/dev/null || echo "")
                    if [[ -n "$mirrors_raw" ]]; then
                        log_info "镜像加速器: 已配置 ✓"
                        log_info "镜像源内容:"
                        sed -n '/"registry-mirrors"/,/]/p' /etc/docker/daemon.json 2>/dev/null | sed 's/^/  /'
                    else
                        log_warn "镜像加速器: 未配置"
                    fi
                fi
            else
                log_warn "Docker配置文件不存在"
            fi
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


# ==================== Docker卸载相关函数 ====================

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

    # 二次确认
    echo
    log_error "最后确认：输入 'YES' 继续卸载，输入其他任何内容取消："
    local final_confirm
    read -rp "> " final_confirm

    # 使用tr进行大小写不敏感比较，以获得更好的兼容性
    if [[ "$(echo "$final_confirm" | tr '[:lower:]' '[:upper:]')" != "YES" ]]; then
        log_info "操作已取消"
        return 0
    fi

    log_info "开始卸载Docker..."

    # 1. 停止Docker服务
    log_info "停止Docker服务..."
    systemctl stop docker.socket >/dev/null 2>&1 || true
    systemctl stop docker >/dev/null 2>&1 || true
    systemctl disable docker >/dev/null 2>&1 || true

    # 2. 清理Docker数据（如果Docker命令还可用）
    if command_exists docker; then
        log_info "清理Docker数据..."
        docker system prune -af --volumes >/dev/null 2>&1 || true
    fi

    # 3. 卸载Docker软件包
    log_info "卸载Docker软件包..."
    if command_exists apt-get; then
        apt-get purge -y \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            docker-compose >/dev/null 2>&1 || true
        apt-get autoremove -y --purge >/dev/null 2>&1 || true

    elif command_exists yum; then
        yum remove -y \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            docker-compose >/dev/null 2>&1 || true
        yum autoremove -y >/dev/null 2>&1 || true

    elif command_exists dnf; then
        dnf remove -y \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            docker-compose >/dev/null 2>&1 || true
        dnf autoremove -y >/dev/null 2>&1 || true
    fi

    # 4. 删除Docker Compose
    log_info "删除Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose

    # 5. 删除Docker数据目录
    log_info "删除Docker数据目录..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf /run/docker*
    rm -rf /var/run/docker*

    # 6. 删除仓库配置
    log_info "清理仓库配置..."
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    rm -f /etc/yum.repos.d/docker-ce.repo

    # 7. 删除用户组
    log_info "删除Docker用户组..."
    groupdel docker >/dev/null 2>&1 || true

    # 8. 清理残留的可执行文件
    log_info "清理残留文件..."
    find /usr/bin /usr/local/bin /sbin /usr/sbin -name "docker*" -type f -delete 2>/dev/null || true

    log_info "Docker卸载完成！"
    log_warn "建议重新登录终端或运行 'hash -r' 清除命令缓存"
}

# ==================== 主菜单和入口函数 ====================

# ==================== 常用软件安装相关函数 ====================

# 生成Redis配置文件
create_redis_config() {
    local config_file="$1"
    cat > "$config_file" <<'EOF'
# Redis 配置文件
bind 0.0.0.0
port 6379
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile /var/log/redis/redis.log
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data
maxmemory 128mb
maxmemory-policy allkeys-lru
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
EOF
}

# 安装Redis服务
install_redis_service() {
    log_purple "开始安装Redis服务..."
    cd "$SCRIPT_START_DIR"
    # 检查Docker和Docker Compose
    if ! command_exists docker || ! command_exists docker-compose; then
        log_error "请先安装Docker和Docker Compose"
        return 1
    fi

    # 检查Docker服务
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker服务未运行，请先启动Docker"
        return 1
    fi

    # 交互式获取用户输入
    echo
    log_info "请配置Redis服务参数："
    
    local container_name="redis"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}
    
    local port="6379"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}
    
    local redis_password=""
    read -rp "Redis密码 (留空则不设置密码): " redis_password
    
    local install_dir="./redis"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}
    
    # 创建安装目录
    mkdir -p "$install_dir"/{data,conf,logs}
    
    # 创建Redis日志子目录并设置权限
    mkdir -p "$install_dir/logs"
    chmod -R 777 "$install_dir/logs"
    
    # 生成Redis配置文件
    create_redis_config "$install_dir/conf/redis.conf"
    
    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  redis:
    image: redis:7.2.4
    restart: always
    container_name: ${container_name}
    networks:
      - app-network
    ports:
      - "${port}:6379"
    command: redis-server /etc/redis/redis.conf ${redis_password:+--requirepass "${redis_password}"}
    volumes:
      - ./data:/data
      - ./conf/redis.conf:/etc/redis/redis.conf
      - ./logs:/var/log/redis

networks:
  app-network:
    driver: bridge
EOF

    # 启动服务
    log_info "正在启动Redis服务..."
    local original_dir="$(pwd)"
    cd "$install_dir"
    
    if docker-compose up -d; then
        log_info "✓ Redis服务启动成功！"
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:6379"
        log_info "  数据目录: $(pwd)/data"
        log_info "  配置文件: $(pwd)/conf/redis.conf"
        log_info "  日志文件: $(pwd)/logs/redis.log"
        
        if [[ -n "$redis_password" ]]; then
            log_info "  Redis密码: ${redis_password}"
        fi
        
        echo
        log_info "常用管理命令："
        log_info "  查看日志: docker-compose logs -f redis"
        log_info "  进入容器: docker exec -it ${container_name} redis-cli"
        log_info "  停止服务: docker-compose down"
        log_info "  重启服务: docker-compose restart"
        
        # 显示服务状态
        sleep 2
        docker-compose ps
        
        # 返回原始目录
        cd "$SCRIPT_START_DIR"
    else
        log_error "Redis服务启动失败"
        cd "$SCRIPT_START_DIR"
        return 1
    fi
}

# 安装MySQL服务
install_mysql_service() {
    log_purple "开始安装MySQL服务..."
    cd "$SCRIPT_START_DIR"
    # 检查Docker和Docker Compose
    if ! command_exists docker || ! command_exists docker-compose; then
        log_error "请先安装Docker和Docker Compose"
        return 1
    fi

    # 检查Docker服务
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker服务未运行，请先启动Docker"
        return 1
    fi

    # 交互式获取用户输入
    echo
    log_info "请配置MySQL服务参数："
    
    local container_name="mysql"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}
    
    local port="3306"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}
    
    local mysql_root_password=""
    read -rp "MySQL root密码: " mysql_root_password
    if [[ -z "$mysql_root_password" ]]; then
        mysql_root_password="$(openssl rand -base64 12)"
        log_info "已生成随机密码: ${mysql_root_password}"
    fi
    
    local mysql_database=""
    read -rp "创建数据库 (留空则不创建): " mysql_database
    
    local install_dir="./mysql"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}
    
    # 创建安装目录
    mkdir -p "$install_dir"/{data,conf,logs,init}
    
    # 生成MySQL配置文件
    cat > "$install_dir/conf/my.cnf" <<'EOF'
[mysqld]
default_authentication_plugin=mysql_native_password
default-time-zone='+08:00'
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_connections=200
innodb_buffer_pool_size=128M
innodb_log_file_size=64M
innodb_flush_log_at_trx_commit=1
innodb_lock_wait_timeout=50
slow_query_log=1
long_query_time=2
slow_query_log_file=/var/log/mysql/slow.log

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOF

    # 生成初始化脚本（如果指定了数据库）
    if [[ -n "$mysql_database" ]]; then
        cat > "$install_dir/init/init.sql" <<EOF
CREATE DATABASE IF NOT EXISTS \`${mysql_database}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${mysql_database}\`.* TO 'root'@'%';
FLUSH PRIVILEGES;
EOF
    fi
    
    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0.35
    restart: always
    container_name: ${container_name}
    networks:
      - app-network
    ports:
      - "${port}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${mysql_root_password}
      ${mysql_database:+MYSQL_DATABASE: ${mysql_database}}
    volumes:
      - ./data:/var/lib/mysql
      - ./conf/my.cnf:/etc/mysql/conf.d/my.cnf
      - ./logs:/var/log/mysql
      ${mysql_database:+- ./init:/docker-entrypoint-initdb.d}

networks:
  app-network:
    driver: bridge
EOF

    # 启动服务
    log_info "正在启动MySQL服务..."
    cd "$install_dir"
    
    if docker-compose up -d; then
        log_info "✓ MySQL服务启动成功！"
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:3306"
        log_info "  数据目录: $(pwd)/data"
        log_info "  配置文件: $(pwd)/conf/my.cnf"
        log_info "  root密码: ${mysql_root_password}"
        
        if [[ -n "$mysql_database" ]]; then
            log_info "  创建数据库: ${mysql_database}"
        fi
        
        echo
        log_info "常用管理命令："
        log_info "  查看日志: docker-compose logs -f mysql"
        log_info "  进入容器: docker exec -it ${container_name} mysql -uroot -p"
        log_info "  停止服务: docker-compose down"
        log_info "  重启服务: docker-compose restart"
        
        # 显示服务状态
        sleep 5
        docker-compose ps
        
        # 返回原始目录
        cd "$SCRIPT_START_DIR"
    else
        log_error "MySQL服务启动失败"
        cd "$SCRIPT_START_DIR"
        return 1
    fi
}

# 安装PostgreSQL服务
install_postgresql_service() {
    log_purple "开始安装PostgreSQL服务..."
    cd "$SCRIPT_START_DIR"

    # 检查Docker和Docker Compose
    if ! command_exists docker || ! command_exists docker-compose; then
        log_error "请先安装Docker和Docker Compose"
        return 1
    fi

    # 检查Docker服务
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker服务未运行，请先启动Docker"
        return 1
    fi

    # 交互式获取用户输入
    echo
    log_info "请配置PostgreSQL服务参数："
    
    local container_name="postgres"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}
    
    local port="5432"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}
    
    local postgres_password=""
    read -rp "PostgreSQL密码: " postgres_password
    if [[ -z "$postgres_password" ]]; then
        postgres_password="$(openssl rand -base64 12)"
        log_info "已生成随机密码: ${postgres_password}"
    fi
    
    local postgres_database=""
    read -rp "创建数据库 (留空则不创建): " postgres_database
    
    local install_dir="./postgres"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}
    
    # 创建安装目录
    mkdir -p "$install_dir"/{data,init}
    
    # 生成初始化脚本（如果指定了数据库）
    if [[ -n "$postgres_database" ]]; then
        cat > "$install_dir/init/init.sql" <<EOF
CREATE DATABASE ${postgres_database};
EOF
    fi
    
    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  postgres:
    image: postgres:15.4
    restart: always
    container_name: ${container_name}
    networks:
      - app-network
    ports:
      - "${port}:5432"
    environment:
      POSTGRES_PASSWORD: ${postgres_password}
      ${postgres_database:+POSTGRES_DB: ${postgres_database}}
    volumes:
      - ./data:/var/lib/postgresql/data
      ${postgres_database:+- ./init:/docker-entrypoint-initdb.d}

networks:
  app-network:
    driver: bridge
EOF

    # 启动服务
    log_info "正在启动PostgreSQL服务..."
    local original_dir="$(pwd)"
    cd "$install_dir"
    
    if docker-compose up -d; then
        log_info "✓ PostgreSQL服务启动成功！"
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:5432"
        log_info "  数据目录: $(pwd)/data"
        log_info "  用户: postgres"
        log_info "  密码: ${postgres_password}"
        
        if [[ -n "$postgres_database" ]]; then
            log_info "  创建数据库: ${postgres_database}"
        fi
        
        echo
        log_info "常用管理命令："
        log_info "  查看日志: docker-compose logs -f postgres"
        log_info "  进入容器: docker exec -it ${container_name} psql -U postgres"
        log_info "  停止服务: docker-compose down"
        log_info "  重启服务: docker-compose restart"
        
        # 显示服务状态
        sleep 5
        docker-compose ps
        
        # 返回原始目录
        cd "$SCRIPT_START_DIR"
    else
        log_error "PostgreSQL服务启动失败"
        cd "$SCRIPT_START_DIR"
        return 1
    fi
}

# 安装Nginx服务
install_nginx_service() {
    log_purple "开始安装Nginx服务..."
    cd "$SCRIPT_START_DIR"
    # 检查Docker和Docker Compose
    if ! command_exists docker || ! command_exists docker-compose; then
        log_error "请先安装Docker和Docker Compose"
        return 1
    fi

    # 检查Docker服务
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker服务未运行，请先启动Docker"
        return 1
    fi

    # 交互式获取用户输入
    echo
    log_info "请配置Nginx服务参数："
    
    local container_name="nginx"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}
    
    local http_port="80"
    read -rp "HTTP端口 [${http_port}]: " input_http_port
    http_port=${input_http_port:-$http_port}
    
    local https_port="443"
    read -rp "HTTPS端口 [${https_port}]: " input_https_port
    https_port=${input_https_port:-$https_port}
    
    local install_dir="./nginx"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}
    
    # 创建安装目录
    mkdir -p "$install_dir"/{conf.d,html,logs,certs}
    
    # 生成Nginx配置文件
    cat > "$install_dir/nginx.conf" <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 生成默认站点配置
    cat > "$install_dir/conf.d/default.conf" <<'EOF'
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF
    
    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  nginx:
    image: nginx:1.25.3
    restart: always
    container_name: ${container_name}
    networks:
      - app-network
    ports:
      - "${http_port}:80"
      - "${https_port}:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./conf.d:/etc/nginx/conf.d
      - ./html:/usr/share/nginx/html
      - ./logs:/var/log/nginx
      - ./certs:/etc/nginx/certs

networks:
  app-network:
    driver: bridge
EOF

    # 启动服务
    log_info "正在启动Nginx服务..."
    local original_dir="$(pwd)"
    cd "$install_dir"
    
    if docker-compose up -d; then
        log_info "✓ Nginx服务启动成功！"
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  HTTP端口: ${http_port}:80"
        log_info "  HTTPS端口: ${https_port}:443"
        log_info "  配置目录: $(pwd)/conf.d"
        log_info "  网站目录: $(pwd)/html"
        log_info "  日志目录: $(pwd)/logs"
        
        echo
        log_info "常用管理命令："
        log_info "  查看日志: docker-compose logs -f nginx"
        log_info "  进入容器: docker exec -it ${container_name} bash"
        log_info "  停止服务: docker-compose down"
        log_info "  重启服务: docker-compose restart"
        log_info "  测试配置: docker exec ${container_name} nginx -t"
        
        # 显示服务状态
        sleep 3
        docker-compose ps
        
        # 返回原始目录
        cd "$SCRIPT_START_DIR"
    else
        log_error "Nginx服务启动失败"
        cd "$SCRIPT_START_DIR"
        return 1
    fi
}

# 常用软件安装菜单
install_common_services() {
    while true; do
        clear
        echo
        echo "================ 常用软件安装 ================"
        echo
        echo "🗄️ 数据库服务:"
        echo "  1. 安装 Redis"
        echo "  2. 安装 MySQL"
        echo "  3. 安装 PostgreSQL"
        echo
        echo "🌐 Web服务:"
        echo "  4. 安装 Nginx"
        echo
        echo "  0. 返回主菜单"
        echo "=============================================="
        echo

        local choice
        read -rp "请选择要安装的软件 [0-4]: " choice

        case $choice in
            1) install_redis_service ;;
            2) install_mysql_service ;;
            3) install_postgresql_service ;;
            4) install_nginx_service ;;
            0) return 0 ;;
            *) log_error "无效选择，请输入 0-4 之间的数字" ;;
        esac

        echo
        log_info "按任意键继续..."
        read -r
    done
}

# 显示主菜单
show_menu() {
    clear
    echo
    echo "================ Docker 管理脚本 v${SCRIPT_VERSION} ================"
    echo
    echo "📋 Docker 状态管理:"
    echo "  1. 查看 Docker 详细状态"
    echo "  2. 查看容器日志"
    echo
    echo "📦 容器管理:"
    echo "  3. 选择启动容器"
    echo "  4. 选择停止容器"
    echo "  5. 选择删除容器"
    echo
    echo "🏗️ 镜像管理:"
    echo "  6. 选择导出镜像"
    echo "  7. 从目录导入镜像"
    echo
    echo "🛠️ 系统管理:"
    echo "  8. 清理 Docker 系统"
    echo "  9. 配置 Docker 镜像加速器"
    echo
    echo "⚙️ 安装配置:"
    echo "  10. 换国内源(apt/yum/dnf)"
    echo "  11. 一键安装 Docker"
    echo "  12. 安装 Docker Compose"
    echo
    echo "🚀 常用软件:"
    echo "  13. 安装常用服务(Redis/MySQL等)"
    echo
    echo "🗑️ 卸载:"
    echo "  14. 完全卸载 Docker"
    echo
    echo "  0. 退出脚本"
    echo "=================================================="
    echo
}

# 主程序入口
main() {
    # 显示脚本信息
    log_info "Docker管理脚本 v${SCRIPT_VERSION} 启动"
    log_info "当前用户: $(whoami)"
    log_info "系统信息: $(uname -sr)"

    while true; do
        show_menu

        local choice
        read -rp "请选择操作 [0-14]: " choice

        echo
        case $choice in
            1) show_docker_status ;;
            2) view_container_logs ;;
            3) start_selected_containers ;;
            4) stop_selected_containers ;;
            5) remove_selected_containers ;;
            6) export_selected_images ;;
            7) import_images_from_dir ;;
            8) clean_docker_system ;;
            9)
                check_root
                change_docker_mirror
                ;;
            10)
                check_root
                local os_type
                os_type=$(detect_os)
                if [[ $? -eq 0 ]]; then
                    case $os_type in
                        ubuntu|debian)
                            change_apt_source
                            ;;
                        centos|rhel|fedora)
                            change_yum_source
                            ;;
                        *)
                            log_error "不支持的操作系统: $os_type"
                            ;;
                    esac
                else
                    log_error "无法检测操作系统类型"
                fi
                ;;
            11)
                check_root
                install_docker
                ;;
            12)
                check_root
                install_docker_compose
                ;;
            13) install_common_services ;;
            14)
                check_root
                uninstall_docker
                ;;
            0)
                log_info "感谢使用Docker管理脚本，再见！"
                exit 0
                ;;
            *)
                log_error "无效选择，请输入 0-14 之间的数字"
                ;;
        esac

        echo
        log_info "操作完成，按任意键返回主菜单..."
        read -r
    done
}

# ==================== 脚本入口点 ====================

# 捕获中断信号，优雅退出
trap 'log_warn "脚本被中断"; exit 130' INT TERM

# 启动主程序
main "$@"