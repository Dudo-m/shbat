#!/bin/bash

# 常用服务安装脚本
# 作者: Docker管理助手
# 版本: 1.0.0
# 描述: 一键安装常用服务(Redis、MySQL、PostgreSQL、Nginx等)

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
readonly SCRIPT_VERSION="1.0.0"

# 脚本启动时的目录
readonly SCRIPT_START_DIR="$(pwd)"

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

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
        echo "  0. 退出脚本"
        echo "=============================================="
        echo

        local choice
        read -rp "请选择要安装的软件 [0-4]: " choice

        case $choice in
            1) install_redis_service ;;
            2) install_mysql_service ;;
            3) install_postgresql_service ;;
            4) install_nginx_service ;;
            0) 
                log_info "感谢使用常用服务安装脚本，再见！"
                exit 0
                ;;
            *) log_error "无效选择，请输入 0-4 之间的数字" ;;
        esac

        echo
        log_info "按任意键继续..."
        read -r
    done
}

# ==================== 脚本入口点 ====================

# 捕获中断信号，优雅退出
trap 'log_warn "脚本被中断"; exit 130' INT TERM

# 主程序入口
main() {
    # 显示脚本信息
    log_info "常用服务安装脚本 v${SCRIPT_VERSION} 启动"
    log_info "当前用户: $(whoami)"
    log_info "系统信息: $(uname -sr)"

    # 启动主程序
    install_common_services
}

# 启动主程序
main "$@"