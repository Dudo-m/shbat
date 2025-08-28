#!/bin/bash

# Docker管理脚本
# 作者: Docker管理助手
# 版本: 1.1

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_blue() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行，请使用sudo"
        exit 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# apt 换源 (适用于 Debian/Ubuntu)
change_apt_source() {
    log_info "正在配置 apt 国内镜像源..."
    if ! command_exists apt-get; then
        log_error "当前系统不是基于 Debian/Ubuntu，无法换 apt 源"
        return 1
    fi

    cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s)
    codename=$(lsb_release -cs)

    cat > /etc/apt/sources.list <<EOF
deb https://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
EOF

    log_info "apt 源已替换为阿里云镜像，开始更新..."
    apt-get update
}

# yum 换源 (适用于 CentOS/RHEL)
change_yum_source() {
    log_info "正在配置 yum 国内镜像源..."
    if ! command_exists yum; then
        log_error "当前系统不是基于 CentOS/RHEL，无法换 yum 源"
        return 1
    fi

    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null

    cat > /etc/yum.repos.d/CentOS-Base.repo <<'EOF'
[base]
name=CentOS-$releasever - Base - aliyun
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates - aliyun
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras - aliyun
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF

    log_info "yum 源已替换为阿里云镜像，开始更新..."
    yum makecache
}
# ===================================================================

# 一键安装Docker (官方源)
install_docker() {
    log_info "开始安装Docker (官方源)..."

    if command_exists docker; then
        log_warn "Docker已经安装，版本信息："
        docker --version
        return 0
    fi

    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
    else
        log_error "无法检测操作系统版本"
        exit 1
    fi

    log_info "检测到操作系统: $OS"

    # 更新系统包并安装依赖
    log_info "更新系统包并安装依赖..."
    if command_exists apt-get; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        # 添加Docker官方GPG密钥
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # 添加Docker仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        # 安装Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io

    elif command_exists yum; then
        yum install -y yum-utils

        # 添加Docker仓库
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

        # 安装Docker
        yum install -y docker-ce docker-ce-cli containerd.io

    else
        log_error "不支持的包管理器，请手动安装Docker"
        exit 1
    fi

    # 启动并设置开机自启Docker服务
    systemctl start docker
    systemctl enable docker

    # 添加当前用户到docker组
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "已将用户 $SUDO_USER 添加到docker组。请重新登录以使更改生效。"
    fi

    log_info "Docker安装完成！"
    docker --version
}

# 一键安装Docker (国内源)
install_docker_cn() {
    log_info "开始安装Docker (国内源)..."

    if command_exists docker; then
        log_warn "Docker已经安装，版本信息："
        docker --version
        return 0
    fi

    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
    else
        log_error "无法检测操作系统版本"
        exit 1
    fi

    log_info "检测到操作系统: $OS"

    # 更新系统包并安装依赖
    log_info "更新系统包并安装依赖..."
    if command_exists apt-get; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        # 添加Docker官方GPG密钥
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # 添加阿里云Docker仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        # 安装Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io

    elif command_exists yum; then
        yum install -y yum-utils

        # 添加阿里云Docker仓库
        yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

        # 安装Docker
        yum install -y docker-ce docker-ce-cli containerd.io

    else
        log_error "不支持的包管理器，请手动安装Docker"
        exit 1
    fi

    # 启动并设置开机自启Docker服务
    systemctl start docker
    systemctl enable docker

    # 添加当前用户到docker组
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "已将用户 $SUDO_USER 添加到docker组。请重新登录以使更改生效。"
    fi

    log_info "Docker安装完成！"
    docker --version
}

# 安装Docker Compose
install_docker_compose() {
    log_info "开始安装Docker Compose..."

    if command_exists docker-compose; then
        log_warn "Docker Compose已经安装，版本信息："
        docker-compose --version
        return 0
    fi

    # 获取最新版本号
    log_info "获取Docker Compose最新版本..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    if [[ -z "$COMPOSE_VERSION" ]]; then
        log_warn "无法获取最新版本，将使用稳定版本 v2.24.6"
        COMPOSE_VERSION="v2.24.6"
    fi

    log_info "下载Docker Compose $COMPOSE_VERSION..."

    # 下载Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # 添加执行权限
    chmod +x /usr/local/bin/docker-compose

    log_info "Docker Compose安装完成！"
    docker-compose --version
}

# Docker换源
change_docker_mirror() {
    log_info "配置Docker镜像源..."

    # 创建docker配置目录
    mkdir -p /etc/docker

    # 配置镜像加速器和日志选项
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
         "https://docker.1panel.live",
         "https://docker.1ms.run",
         "https://dytt.online",
         "https://docker-0.unsee.tech",
         "https://lispy.org",
         "https://docker.xiaogenban1993.com",
         "https://666860.xyz",
         "https://hub.rat.dev",
         "https://docker.m.daocloud.io",
         "https://demo.52013120.xyz",
         "https://proxy.vvvv.ee",
         "https://registry.cyou",
         "https://mirror.ccs.tencentyun.com",
         "https://<your_code>.mirror.aliyuncs.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF

    # 重启Docker服务
    log_info "重启Docker服务以应用配置..."
    systemctl daemon-reload
    systemctl restart docker

    log_info "Docker镜像源配置完成！"
}

# 停止所有容器
stop_all_containers() {
    log_info "停止所有运行中的容器..."
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    running_containers=$(docker ps -q)
    if [[ -z "$running_containers" ]]; then
        log_warn "没有运行中的容器"
        return 0
    fi

    docker stop $running_containers
    log_info "所有运行中的容器已停止"
}

# 删除所有容器
remove_all_containers() {
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    log_warn "这将删除所有容器（包括已停止的），是否继续？[y/N]"
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        log_info "操作已取消"
        return 0
    fi

    log_info "删除所有容器..."
    all_containers=$(docker ps -aq)
    if [[ -z "$all_containers" ]]; then
        log_warn "没有容器需要删除"
        return 0
    fi

    # 先停止所有容器，忽略错误，然后删除
    docker stop $all_containers > /dev/null 2>&1
    docker rm $all_containers

    log_info "所有容器已删除"
}

# 启动所有已停止的容器
start_all_containers() {
    log_info "启动所有已停止的容器..."
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    stopped_containers=$(docker ps -aq -f status=exited)
    if [[ -z "$stopped_containers" ]]; then
        log_warn "没有已停止的容器需要启动"
        return 0
    fi

    docker start $stopped_containers
    log_info "所有已停止的容器已启动"
}

# 卸载Docker
uninstall_docker() {
    log_warn "这将完全卸载Docker和Docker Compose，包括所有容器、镜像和数据卷，是否继续？[y/N]"
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        log_info "操作已取消"
        return 0
    fi

    log_info "开始卸载Docker..."

    # 停止Docker服务
    log_info "停止并禁用Docker服务..."
    systemctl stop docker > /dev/null 2>&1 || true
    systemctl disable docker > /dev/null 2>&1 || true

    # 清理所有Docker数据
    log_info "清理所有Docker数据 (容器、镜像、数据卷、网络)..."
    if command_exists docker; then
        docker system prune -af --volumes > /dev/null 2>&1
    else
        log_warn "Docker命令不可用，跳过 'docker system prune'。"
    fi

    # 卸载Docker包
    if command_exists apt-get; then
        log_info "卸载Docker包 (Debian/Ubuntu)..."
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        apt-get autoremove -y --purge
    elif command_exists yum; then
        log_info "卸载Docker包 (CentOS/RHEL)..."
        yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        yum autoremove -y
    else
        log_warn "不支持的包管理器，请手动卸载Docker相关包。"
    fi

    # 删除Docker Compose
    log_info "删除Docker Compose可执行文件..."
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose # 检查并删除 /usr/bin 下的链接

    # 删除Docker相关文件和目录
    log_info "删除Docker相关数据目录和配置文件..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf /run/docker # 删除运行时文件

    # 删除GPG密钥和仓库配置
    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        log_info "删除Docker APT仓库配置..."
        rm -f /etc/apt/sources.list.d/docker.list
        rm -f /etc/apt/keyrings/docker.gpg # 新的GPG密钥位置
        rm -f /usr/share/keyrings/docker-archive-keyring.gpg # 旧的GPG密钥位置
    elif [[ -f /etc/yum.repos.d/docker-ce.repo ]]; then
        log_info "删除Docker YUM仓库配置..."
        rm -f /etc/yum.repos.d/docker-ce.repo
    fi

    # 删除Docker用户组
    log_info "删除Docker用户组..."
    groupdel docker > /dev/null 2>&1 || true

    # 查找并删除可能残留的docker二进制文件
    log_info "查找并删除可能残留的 'docker' 客户端二进制文件..."
    find /usr/bin /usr/local/bin -name "docker*" -executable -delete 2>/dev/null || true
    find /sbin /usr/sbin -name "docker*" -executable -delete 2>/dev/null || true

    log_info "Docker卸载完成！"
    log_warn "注意：为了确保 'docker' 命令不再可用，您可能需要重新登录您的终端会话，或者运行 'hash -r' 来清除 shell 的命令缓存。"
}

# 创建导入脚本（公共函数）
create_import_script() {
    local export_dir="$1"
    local import_script="$export_dir/import_images.sh"

    cat > "$import_script" <<'EOF'
#!/bin/bash
# Docker镜像导入脚本 (自动生成)

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查Docker是否安装
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker未安装，请先安装Docker后再运行此脚本"
    exit 1
fi

log_info "开始导入Docker镜像..."
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tar_files=$(find "$script_dir" -maxdepth 1 -name "*.tar" -type f)

if [[ -z "$tar_files" ]]; then
    log_error "在脚本所在目录未找到任何 .tar 镜像文件"
    exit 1
fi

total_files=$(echo "$tar_files" | wc -l)
current=0

for tar_file in $tar_files; do
    current=$((current + 1))
    filename=$(basename "$tar_file")
    log_info "[$current/$total_files] 正在导入: $filename"

    if docker load -i "$tar_file"; then
        log_info "✓ 导入成功: $filename"
    else
        log_error "✗ 导入失败: $filename"
    fi
done

log_info "所有镜像导入完成！"
log_info "当前镜像列表："
docker images
EOF

    chmod +x "$import_script"
}

# 导出所有镜像
export_all_images() {
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    log_info "开始导出所有本地镜像..."
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")

    if [[ -z "$images" ]]; then
        log_warn "没有可导出的镜像"
        return 0
    fi

    export_dir="./docker_images_all_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    log_info "镜像将导出到: $export_dir"

    # 创建导入脚本
    create_import_script "$export_dir"

    total=$(echo "$images" | wc -l)
    current=0

    echo "$images" | while read -r image; do
        current=$((current + 1))
        safe_name=$(echo "$image" | sed 's|[/:]|_|g')
        tar_file="$export_dir/${safe_name}.tar"

        log_info "[$current/$total] 正在导出: $image"
        if docker save -o "$tar_file" "$image"; then
            log_info "✓ 导出成功: $tar_file"
        else
            log_error "✗ 导出失败: $image"
        fi
    done

    log_info "所有镜像导出完成！"
    log_info "要导入这些镜像，请将 '$export_dir' 目录拷贝到目标机器并运行:"
    log_info "cd $export_dir && ./import_images.sh"
}

# 自选镜像导出
export_selected_images() {
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    log_info "获取本地镜像列表..."
    image_list=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")

    if [[ -z "$image_list" ]]; then
        log_warn "没有可用的镜像"
        return 0
    fi

    log_blue "--- 本地镜像列表 ---"
    i=1
    while read -r image; do
        printf "%-4s %s\n" "$i" "$image"
        i=$((i + 1))
    done <<< "$image_list"
    log_blue "--------------------"

    log_info "请选择要导出的镜像："
    log_info " - 输入镜像编号（用空格分隔多个编号），例如: 1 3 5"
    log_info " - 输入 'all' 导出所有镜像"
    log_info " - 输入 'q' 退出"
    read -rp "请输入你的选择: " selection

    if [[ "$selection" == "q" || -z "$selection" ]]; then
        log_info "操作已取消"
        return 0
    fi

    selected_images=""
    if [[ "$selection" == "all" ]]; then
        selected_images="$image_list"
    else
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]]; then
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
        selected_images=$(echo -e "$selected_images" | grep -v '^$')
    fi

    if [[ -z "$selected_images" ]]; then
        log_error "没有有效的镜像被选中"
        return 1
    fi

    log_info "已选择以下镜像进行导出："
    echo "$selected_images"
    read -rp "确认导出？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        log_info "操作已取消"
        return 0
    fi

    export_dir="./docker_images_selected_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    log_info "镜像将导出到: $export_dir"

    create_import_script "$export_dir"

    total=$(echo "$selected_images" | wc -l)
    current=0

    echo "$selected_images" | while read -r image; do
        current=$((current + 1))
        safe_name=$(echo "$image" | sed 's|[/:]|_|g')
        tar_file="$export_dir/${safe_name}.tar"

        log_info "[$current/$total] 正在导出: $image"
        if docker save -o "$tar_file" "$image"; then
            log_info "✓ 导出成功: $tar_file"
        else
            log_error "✗ 导出失败: $image"
        fi
    done

    log_info "选中镜像导出完成！"
    log_info "要导入这些镜像，请将 '$export_dir' 目录拷贝到目标机器并运行:"
    log_info "cd $export_dir && ./import_images.sh"
}

# 从目录导入镜像
import_images_from_dir() {
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    read -rp "请输入包含 .tar 镜像文件的目录路径: " import_dir

    if [[ -z "$import_dir" ]]; then
        log_error "目录路径不能为空"
        return 1
    fi

    if [[ ! -d "$import_dir" ]]; then
        log_error "目录不存在: $import_dir"
        return 1
    fi

    log_info "从目录导入镜像: $import_dir"
    tar_files=$(find "$import_dir" -maxdepth 1 -name "*.tar" -type f)

    if [[ -z "$tar_files" ]]; then
        log_warn "在目录 $import_dir 中未找到 .tar 文件"
        return 0
    fi

    total=$(echo "$tar_files" | wc -l)
    current=0

    echo "$tar_files" | while read -r tar_file; do
        current=$((current + 1))
        filename=$(basename "$tar_file")

        log_info "[$current/$total] 正在导入: $filename"
        if docker load -i "$tar_file"; then
            log_info "✓ 导入成功: $filename"
        else
            log_error "✗ 导入失败: $filename"
        fi
    done

    log_info "镜像导入完成！"
}

# 查看Docker状态
show_docker_status() {
    log_info "Docker服务状态:"
    systemctl status docker --no-pager -l || log_error "无法获取Docker服务状态，可能未安装或未运行"

    if ! command_exists docker; then
        log_warn "Docker命令不存在，请先安装Docker"
        return 1
    fi

    echo
    log_info "Docker版本信息:"
    docker version

    if command_exists docker-compose; then
        echo
        log_info "Docker Compose版本信息:"
        docker-compose version
    fi

    echo
    log_info "运行中的容器:"
    docker ps

    echo
    log_info "本地镜像列表:"
    docker images

    echo
    log_info "Docker磁盘使用情况:"
    docker system df
}

# 清理Docker系统
clean_docker_system() {
    if ! command_exists docker; then
        log_error "Docker未安装或未运行。"
        return 1
    fi

    log_warn "这将清理所有未使用的容器、网络、镜像和构建缓存，是否继续？[y/N]"
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        log_info "操作已取消"
        return 0
    fi

    log_info "正在清理Docker系统..."
    docker system prune -af --volumes
    log_info "Docker系统清理完成！"
}

# 显示菜单
show_menu() {
    echo
    log_blue "========== Docker 管理脚本 =========="
    echo " 1. 查看 Docker 状态"
    echo " 2. 停止所有容器"
    echo " 3. 删除所有容器"
    echo " 4. 启动所有已停止的容器"
    echo " 5. 导出所有本地镜像"
    echo " 6. 自选导出本地镜像"
    echo " 7. 从指定目录导入镜像"
    echo " 8. 清理 Docker 系统"
    echo " 9. 配置 Docker 镜像加速"
    echo " 10. 一键安装 Docker (官方源)"
    echo " 11. 一键安装 Docker (国内源)"
    echo " 12. 安装 Docker Compose"
    echo " 13. 切换系统软件源 (apt/yum)"
    echo " 14. 完全卸载 Docker"
    echo " 0. 退出脚本"
    log_blue "==================================="
    echo
}

# 主函数
main() {
    while true; do
        show_menu
        read -rp "请选择操作 [0-14]: " choice

        case $choice in
            1) show_docker_status ;;
            2) stop_all_containers ;;
            3) remove_all_containers ;;
            4) start_all_containers ;;
            5) export_all_images ;;
            6) export_selected_images ;;
            7) import_images_from_dir ;;
            8) clean_docker_system ;;
            9) check_root; change_docker_mirror ;;
            10) check_root; install_docker ;;
            11) check_root; install_docker_cn ;;
            12) check_root; install_docker_compose ;;
            13)
                check_root
                if command_exists apt-get; then
                    change_apt_source
                elif command_exists yum; then
                    change_yum_source
                else
                    log_error "未检测到 apt-get 或 yum，无法换源"
                fi
                ;;
            14) check_root; uninstall_docker ;;
            0)
                log_info "感谢使用，脚本退出。"
                exit 0
                ;;
            *)
                log_error "无效选择，请输入 0-14 之间的数字。"
                ;;
        esac

        echo
        read -rp "按任意键返回主菜单..."
    done
}

# 脚本入口
main