#!/bin/bash

# 常用服务安装脚本
# 作者: Docker管理助手
# 版本: 2.0.0
# 描述: 一键安装常用服务(Redis、MySQL、PostgreSQL、Nginx、ES、Kibana、Neo4j、ClickHouse、MinIO等)

set -euo pipefail

# ==================== 全局变量和配置 ====================

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 脚本版本
readonly SCRIPT_VERSION="2.0.0"

# 脚本启动时的目录
readonly SCRIPT_START_DIR="$(pwd)"

# 默认网络名称
readonly DEFAULT_NETWORK="app-network"

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

log_cyan() {
    echo -e "${CYAN}[CONFIG]${NC} $(date '+%H:%M:%S') $1"
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

# 获取本机IP地址
get_local_ip() {
    local ip=""
    # 尝试多种方式获取本机IP
    if command -v ip >/dev/null 2>&1; then
        # Linux环境使用ip命令
        ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' 2>/dev/null)
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用ifconfig命令
        ip=$(ifconfig | grep -E '192\.|10\.|172\.' | grep -v '127.0.0.1' | awk '{print $2}' | head -1 2>/dev/null)
    elif command -v hostname >/dev/null 2>&1; then
        # 使用hostname命令
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' 2>/dev/null)
    fi
    
    # 如果上述方法都失败，尝试使用PowerShell (Windows环境)
    if [[ -z "$ip" ]] && command -v powershell.exe >/dev/null 2>&1; then
        ip=$(powershell.exe -Command "(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi','以太网*','Ethernet*' | Where-Object {\$_.IPAddress -notlike '169.254.*' -and \$_.IPAddress -ne '127.0.0.1'} | Select-Object -First 1).IPAddress" 2>/dev/null | tr -d '\r')
    fi
    
    # 如果仍然没有获取到IP，返回localhost
    if [[ -z "$ip" || "$ip" == "127.0.0.1" ]]; then
        echo "localhost"
    else
        echo "$ip"
    fi
}

# 生成随机密码
generate_password() {
    local length="${1:-12}"
    if command -v openssl >/dev/null 2>&1; then
        # 优先使用openssl，但是使用hex格式避免特殊字符
        openssl rand -hex $((length/2)) 2>/dev/null || openssl rand -base64 "$length" 2>/dev/null | tr -d '/+=' | head -c "$length"
    elif [[ -e /dev/urandom ]]; then
        # 使用/dev/urandom生成只包含字母数字的密码
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length" 2>/dev/null || echo "password123"
    else
        # 备用方案：使用时间戳生成简单密码
        echo "pass$(date +%s | tail -c 8)"
    fi
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tulpn | grep -q ":$port "; then
        log_warn "端口 $port 已被占用"
        return 1
    fi
    return 0
}

# 验证Docker环境
validate_docker_environment() {
    # 检查Docker和Docker Compose
    if ! command_exists docker; then
        log_error "Docker 未安装，请先安装 Docker"
        log_info "安装指令: curl -fsSL https://get.docker.com | bash"
        return 1
    fi

    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose 未安装或不可用"
        log_info "请安装 Docker Compose V2 或独立的 docker-compose"
        return 1
    fi

    # 检查Docker服务
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 服务未运行，请先启动 Docker 服务"
        log_info "启动命令: sudo systemctl start docker"
        return 1
    fi

    return 0
}

# 获取Docker Compose命令
get_docker_compose_cmd() {
    if command_exists docker-compose; then
        echo "docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        log_error "找不到可用的 Docker Compose 命令"
        return 1
    fi
}

# 通用服务启动函数
start_service() {
    local service_name="$1"
    local install_dir="$2"
    local container_name="$3"

    log_info "正在启动 ${service_name} 服务..."

    local original_dir="$(pwd)"
    cd "$install_dir"

    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || return 1

    if $compose_cmd up -d; then
        log_info "✓ ${service_name} 服务启动成功！"

        echo
        log_info "常用管理命令："
        log_info "  查看日志: $compose_cmd logs -f"
        log_info "  进入容器: docker exec -it ${container_name} bash"
        log_info "  停止服务: $compose_cmd down"
        log_info "  重启服务: $compose_cmd restart"

        # 显示服务状态
        sleep 3
        $compose_cmd ps

        cd "$original_dir"
        return 0
    else
        log_error "${service_name} 服务启动失败"
        cd "$original_dir"
        return 1
    fi
}

# ==================== 服务安装函数 ====================

# 安装Redis服务
install_redis_service() {
    log_purple "开始安装 Redis 服务..."

    validate_docker_environment || return 1

    # 交互式获取用户输入
    echo
    log_cyan "请配置 Redis 服务参数："

    local container_name="redis"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local port="6379"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}

    # 检查端口
    if ! check_port "$port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local redis_password=""
    read -rp "Redis 密码 (留空则不设置密码): " redis_password

    local install_dir="./redis"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{data,conf,logs}
    chmod 777 "$install_dir/logs"

    # 生成Redis配置文件
    cat > "$install_dir/conf/redis.conf" <<'EOF'
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
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
EOF

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  redis:
    image: redis:7.2.4-alpine
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${port}:6379"
    command: redis-server /etc/redis/redis.conf ${redis_password:+--requirepass "${redis_password}"}
    volumes:
      - ./data:/data
      - ./conf/redis.conf:/etc/redis/redis.conf
      - ./logs:/var/log/redis
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "Redis" "$install_dir" "$container_name"; then
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:6379"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  配置文件: $(realpath $install_dir)/conf/redis.conf"

        if [[ -n "$redis_password" ]]; then
            log_info "  Redis 密码: ${redis_password}"
            log_info "  连接命令: redis-cli -h localhost -p ${port} -a ${redis_password}"
        else
            log_info "  连接命令: redis-cli -h localhost -p ${port}"
        fi
    fi
}

# 安装MySQL服务
install_mysql_service() {
    log_purple "开始安装 MySQL 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 MySQL 服务参数："

    local container_name="mysql"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local port="3306"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}

    if ! check_port "$port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local mysql_root_password=""
    read -rp "MySQL root 密码 (留空自动生成): " mysql_root_password
    if [[ -z "$mysql_root_password" ]]; then
        mysql_root_password="$(generate_password 16)"
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
innodb_buffer_pool_size=256M
innodb_log_file_size=64M
innodb_flush_log_at_trx_commit=1
innodb_lock_wait_timeout=50
slow_query_log=1
long_query_time=2
slow_query_log_file=/var/log/mysql/slow.log
general_log=0
general_log_file=/var/log/mysql/general.log

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOF

    # 生成初始化脚本
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
      - ${DEFAULT_NETWORK}
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
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p${mysql_root_password}"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "MySQL" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:3306"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  root 密码: ${mysql_root_password}"
        log_info "  连接命令: mysql -h ${local_ip} -P ${port} -u root -p"

        if [[ -n "$mysql_database" ]]; then
            log_info "  创建数据库: ${mysql_database}"
        fi
    fi
}

# 安装PostgreSQL服务
install_postgresql_service() {
    log_purple "开始安装 PostgreSQL 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 PostgreSQL 服务参数："

    local container_name="postgres"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local port="5432"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}

    if ! check_port "$port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local postgres_password=""
    read -rp "PostgreSQL 密码 (留空自动生成): " postgres_password
    if [[ -z "$postgres_password" ]]; then
        postgres_password="$(generate_password 16)"
        log_info "已生成随机密码: ${postgres_password}"
    fi

    local postgres_database=""
    read -rp "创建数据库 (留空则不创建): " postgres_database

    local install_dir="./postgres"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{data,init}

    # 生成初始化脚本
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
    image: postgres:15.4-alpine
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${port}:5432"
    environment:
      POSTGRES_PASSWORD: ${postgres_password}
      ${postgres_database:+POSTGRES_DB: ${postgres_database}}
      POSTGRES_USER: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./data:/var/lib/postgresql/data
      ${postgres_database:+- ./init:/docker-entrypoint-initdb.d}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "PostgreSQL" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:5432"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  用户名: postgres"
        log_info "  密码: ${postgres_password}"
        log_info "  连接命令: psql -h ${local_ip} -p ${port} -U postgres"

        if [[ -n "$postgres_database" ]]; then
            log_info "  创建数据库: ${postgres_database}"
        fi
    fi
}

# 安装Nginx服务
install_nginx_service() {
    log_purple "开始安装 Nginx 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 Nginx 服务参数："

    local container_name="nginx"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local http_port="80"
    read -rp "HTTP 端口 [${http_port}]: " input_http_port
    http_port=${input_http_port:-$http_port}

    local https_port="443"
    read -rp "HTTPS 端口 [${https_port}]: " input_https_port
    https_port=${input_https_port:-$https_port}

    local install_dir="./nginx"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{conf.d,html,logs,certs}

    # 生成默认首页
    cat > "$install_dir/html/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to nginx!</title>
    <meta charset="utf-8">
    <style>
        body { width: 35em; margin: 0 auto; font-family: Tahoma, Verdana, Arial, sans-serif; }
        h1 { color: #2c5aa0; }
        .info { background: #f0f8ff; padding: 10px; border-left: 4px solid #2c5aa0; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <div class="info">
        <p>If you see this page, the nginx web server is successfully installed and working.</p>
        <p>For online documentation and support please refer to <a href="http://nginx.org/">nginx.org</a>.</p>
    </div>
    <p><em>Thank you for using nginx.</em></p>
</body>
</html>
EOF

    # 生成Nginx主配置文件
    cat > "$install_dir/nginx.conf" <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
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
    client_max_body_size 64M;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

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
        try_files $uri $uri/ =404;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
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
    image: nginx:1.25.3-alpine
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${http_port}:80"
      - "${https_port}:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./conf.d:/etc/nginx/conf.d
      - ./html:/usr/share/nginx/html
      - ./logs:/var/log/nginx
      - ./certs:/etc/nginx/certs
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "Nginx" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  HTTP 端口: ${http_port}:80"
        log_info "  HTTPS 端口: ${https_port}:443"
        log_info "  配置目录: $(realpath $install_dir)/conf.d"
        log_info "  网站目录: $(realpath $install_dir)/html"
        log_info "  访问地址: http://${local_ip}:${http_port}"
        log_info "  配置测试: docker exec ${container_name} nginx -t"
    fi
}

# 安装Elasticsearch服务
install_elasticsearch_service() {
    log_purple "开始安装 Elasticsearch 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 Elasticsearch 服务参数："

    local container_name="elasticsearch"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local port="9200"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}

    if ! check_port "$port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local cluster_name="docker-cluster"
    read -rp "集群名称 [${cluster_name}]: " input_cluster
    cluster_name=${input_cluster:-$cluster_name}

    local heap_size="1g"
    read -rp "堆内存大小 [${heap_size}]: " input_heap
    heap_size=${input_heap:-$heap_size}

    local install_dir="./elasticsearch"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{data,logs,config}

    # 设置正确的权限 (Elasticsearch需要1000:1000)
    chmod 777 "$install_dir/data" "$install_dir/logs"

    # 生成Elasticsearch配置文件
    cat > "$install_dir/config/elasticsearch.yml" <<EOF
cluster.name: "${cluster_name}"
node.name: "node-1"
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.monitoring.collection.enabled: true
path.data: /usr/share/elasticsearch/data
path.logs: /usr/share/elasticsearch/logs
EOF

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  elasticsearch:
    image: elasticsearch:8.11.0
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${port}:9200"
      - "9300:9300"
    environment:
      - "ES_JAVA_OPTS=-Xms${heap_size} -Xmx${heap_size}"
      - "discovery.type=single-node"
      - "xpack.security.enabled=false"
      - "cluster.name=${cluster_name}"
    volumes:
      - ./data:/usr/share/elasticsearch/data
      - ./logs:/usr/share/elasticsearch/logs
      - ./config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "Elasticsearch" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  HTTP 端口: ${port}:9200"
        log_info "  传输端口: 9300:9300"
        log_info "  集群名称: ${cluster_name}"
        log_info "  堆内存: ${heap_size}"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  健康检查: curl http://${local_ip}:${port}/_cluster/health"
        log_info "  访问地址: http://${local_ip}:${port}"
    fi
}

# 安装Kibana服务
install_kibana_service() {
    log_purple "开始安装 Kibana 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 Kibana 服务参数："

    local container_name="kibana"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local port="5601"
    read -rp "映射端口 [${port}]: " input_port
    port=${input_port:-$port}

    if ! check_port "$port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local es_hosts="http://localhost:9200"
    read -rp "Elasticsearch 地址 [${es_hosts}]: " input_hosts
    es_hosts=${input_hosts:-$es_hosts}

    local install_dir="./kibana"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{config,data}

    # 设置权限 - 确保Docker容器内的kibana用户能够写入UUID文件
    chmod 777 "$install_dir/data"

    # 生成Kibana配置文件
    cat > "$install_dir/config/kibana.yml" <<EOF
server.name: kibana
server.host: 0.0.0.0
server.port: 5601
elasticsearch.hosts: ["${es_hosts}"]
monitoring.ui.container.elasticsearch.enabled: true
i18n.locale: "zh-CN"
EOF

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  kibana:
    image: kibana:8.11.0
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${port}:5601"
    environment:
      ELASTICSEARCH_HOSTS: "${es_hosts}"
      I18N_LOCALE: "zh-CN"
    volumes:
      - ./config/kibana.yml:/usr/share/kibana/config/kibana.yml
      - ./data:/usr/share/kibana/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "Kibana" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  端口映射: ${port}:5601"
        log_info "  Elasticsearch: ${es_hosts}"
        log_info "  配置文件: $(realpath $install_dir)/config/kibana.yml"
        log_info "  访问地址: http://${local_ip}:${port}"
        log_warn "注意: 请确保 Elasticsearch 服务已启动并可访问"
    fi
}

# 安装Neo4j服务
install_neo4j_service() {
    log_purple "开始安装 Neo4j 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 Neo4j 服务参数："

    local container_name="neo4j"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local http_port="7474"
    read -rp "HTTP 端口 [${http_port}]: " input_http_port
    http_port=${input_http_port:-$http_port}

    local bolt_port="7687"
    read -rp "Bolt 端口 [${bolt_port}]: " input_bolt_port
    bolt_port=${input_bolt_port:-$bolt_port}

    if ! check_port "$http_port" || ! check_port "$bolt_port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local neo4j_password=""
    read -rp "Neo4j 密码 (留空自动生成): " neo4j_password
    if [[ -z "$neo4j_password" ]]; then
        # 生成只包含字母数字的密码，避免特殊字符导致NEO4J_AUTH解析错误
        if command -v openssl >/dev/null 2>&1; then
            # 使用openssl生成随机字符串，然后过滤掉特殊字符
            neo4j_password="$(openssl rand -hex 8)"
        elif [[ -e /dev/urandom ]]; then
            # 使用/dev/urandom生成
            neo4j_password="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16 2>/dev/null || echo "neo4jpass123")"
        else
            # 备用方案：使用时间戳生成简单密码
            neo4j_password="neo4j$(date +%s | tail -c 6)"
        fi
        log_info "已生成随机密码: ${neo4j_password}"
    fi

    local install_dir="./neo4j"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{data,logs,import,plugins}

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  neo4j:
    image: neo4j:5.13.0-community
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${http_port}:7474"
      - "${bolt_port}:7687"
    environment:
      NEO4J_AUTH: neo4j/${neo4j_password}
      NEO4J_PLUGINS: '["apoc"]'
      NEO4J_dbms_security_procedures_unrestricted: gds.*,apoc.*
      NEO4J_dbms_security_procedures_allowlist: gds.*,apoc.*
      NEO4J_apoc_export_file_enabled: true
      NEO4J_apoc_import_file_enabled: true
      NEO4J_apoc_import_file_use__neo4j__config: true
      NEO4J_ACCEPT_LICENSE_AGREEMENT: yes
    volumes:
      - ./data:/data
      - ./logs:/logs
      - ./import:/var/lib/neo4j/import
      - ./plugins:/plugins
    healthcheck:
      test: ["CMD", "cypher-shell", "-u", "neo4j", "-p", "${neo4j_password}", "RETURN 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "Neo4j" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  HTTP 端口: ${http_port}:7474"
        log_info "  Bolt 端口: ${bolt_port}:7687"
        log_info "  用户名: neo4j"
        log_info "  密码: ${neo4j_password}"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  Web界面: http://${local_ip}:${http_port}"
        log_info "  连接字符串: bolt://${local_ip}:${bolt_port}"
    fi
}

# 安装ClickHouse服务
install_clickhouse_service() {
    log_purple "开始安装 ClickHouse 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 ClickHouse 服务参数："

    local container_name="clickhouse"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local http_port="8123"
    read -rp "HTTP 端口 [${http_port}]: " input_http_port
    http_port=${input_http_port:-$http_port}

    local native_port="9000"
    read -rp "Native 端口 [${native_port}]: " input_native_port
    native_port=${input_native_port:-$native_port}

    if ! check_port "$http_port" || ! check_port "$native_port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local clickhouse_user="admin"
    read -rp "用户名 [${clickhouse_user}]: " input_user
    clickhouse_user=${input_user:-$clickhouse_user}

    local clickhouse_password=""
    read -rp "${clickhouse_user} 密码 (留空自动生成): " clickhouse_password
    if [[ -z "$clickhouse_password" ]]; then
        clickhouse_password="$(generate_password 16)"
        log_info "已生成随机密码: ${clickhouse_password}"
    fi

    local install_dir="./clickhouse"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{data,log,config.d,users.d}

    # 生成ClickHouse主配置文件
    cat > "$install_dir/config.d/config.xml" <<EOF
<clickhouse>
    <!-- Listen wildcard address to allow accepting connections from other containers and host network. -->
    <listen_host>::</listen_host>
    <listen_host>0.0.0.0</listen_host>
    <listen_try>1</listen_try>

    <!--
    <logger>
        <console>1</console>
    </logger> 
    -->
</clickhouse>
EOF

    # 生成用户配置文件
    cat > "$install_dir/users.d/root.xml" <<EOF
<clickhouse>
    <users>
        <${clickhouse_user}>
            <password>${clickhouse_password}</password>
            <networks>
                <ip>::/0</ip> 
            </networks>
            <access_management>1</access_management>
            <named_collection_control>1</named_collection_control>
        </${clickhouse_user}>
    </users>
</clickhouse>
EOF

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: ${container_name}
    restart: always
    privileged: true
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${http_port}:8123"
      - "${native_port}:9000"
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    environment:
      TZ: Asia/Shanghai
    volumes:
      - ./data:/var/lib/clickhouse
      - ./config.d:/etc/clickhouse-server/config.d
      - ./users.d:/etc/clickhouse-server/users.d
      - ./log:/var/log/clickhouse-server
    healthcheck:
      test: ["CMD", "clickhouse-client", "--user", "${clickhouse_user}", "--password", "${clickhouse_password}", "--query", "SELECT 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "ClickHouse" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  HTTP 端口: ${http_port}:8123"
        log_info "  Native 端口: ${native_port}:9000"
        log_info "  管理员用户名: ${clickhouse_user}"
        log_info "  管理员密码: ${clickhouse_password}"
        log_info "  连接命令: clickhouse-client --host ${local_ip} --port ${native_port} --user ${clickhouse_user} --password ${clickhouse_password}"
        log_info "  Web界面: http://${local_ip}:${http_port}/play"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  配置目录: $(realpath $install_dir)/config.d"
        log_info "  用户配置: $(realpath $install_dir)/users.d"
        log_warn "注意: 访问Web界面时请使用管理员用户名和密码登录"
    fi
}

# 安装MinIO服务
install_minio_service() {
    log_purple "开始安装 MinIO 服务..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 MinIO 服务参数："

    local container_name="minio"
    read -rp "容器名称 [${container_name}]: " input_name
    container_name=${input_name:-$container_name}

    local api_port="9000"
    read -rp "API 端口 [${api_port}]: " input_api_port
    api_port=${input_api_port:-$api_port}

    local console_port="9001"
    read -rp "控制台端口 [${console_port}]: " input_console_port
    console_port=${input_console_port:-$console_port}

    if ! check_port "$api_port" || ! check_port "$console_port"; then
        if ! confirm_action "端口被占用，是否继续？"; then
            return 1
        fi
    fi

    local root_user="admin"
    read -rp "Root 用户名 [${root_user}]: " input_user
    root_user=${input_user:-$root_user}

    local root_password=""
    read -rp "Root 密码 (留空自动生成): " root_password
    if [[ -z "$root_password" ]]; then
        root_password="$(generate_password 16)"
        log_info "已生成随机密码: ${root_password}"
    fi

    local install_dir="./minio"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{data,config}

    # 生成MinIO环境配置
    cat > "$install_dir/config/minio.env" <<EOF
MINIO_ROOT_USER=${root_user}
MINIO_ROOT_PASSWORD=${root_password}
MINIO_BROWSER_REDIRECT_URL=http://localhost:${console_port}
MINIO_SERVER_URL=http://localhost:${api_port}
EOF

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  minio:
    image: minio/minio:RELEASE.2023-10-25T06-33-25Z
    restart: always
    container_name: ${container_name}
    networks:
      - ${DEFAULT_NETWORK}
    ports:
      - "${api_port}:9000"
      - "${console_port}:9001"
    environment:
      MINIO_ROOT_USER: ${root_user}
      MINIO_ROOT_PASSWORD: ${root_password}
      MINIO_BROWSER_REDIRECT_URL: http://localhost:${console_port}
      MINIO_SERVER_URL: http://localhost:${api_port}
    command: server /data --console-address ":9001"
    volumes:
      - ./data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ${DEFAULT_NETWORK}:
    driver: bridge
EOF

    # 启动服务
    if start_service "MinIO" "$install_dir" "$container_name"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "配置信息："
        log_info "  容器名称: ${container_name}"
        log_info "  API 端口: ${api_port}:9000"
        log_info "  控制台端口: ${console_port}:9001"
        log_info "  Root 用户: ${root_user}"
        log_info "  Root 密码: ${root_password}"
        log_info "  数据目录: $(realpath $install_dir)/data"
        log_info "  API 地址: http://${local_ip}:${api_port}"
        log_info "  控制台: http://${local_ip}:${console_port}"
    fi
}

# ELK Stack安装 (Elasticsearch + Kibana)
install_elk_stack() {
    log_purple "开始安装 ELK Stack (Elasticsearch + Kibana)..."

    validate_docker_environment || return 1

    echo
    log_cyan "请配置 ELK Stack 参数："

    local es_port="9200"
    read -rp "Elasticsearch 端口 [${es_port}]: " input_es_port
    es_port=${input_es_port:-$es_port}

    local kibana_port="5601"
    read -rp "Kibana 端口 [${kibana_port}]: " input_kibana_port
    kibana_port=${input_kibana_port:-$kibana_port}

    local heap_size="1g"
    read -rp "ES 堆内存大小 [${heap_size}]: " input_heap
    heap_size=${input_heap:-$heap_size}

    local install_dir="./elk-stack"
    read -rp "安装目录 [${install_dir}]: " input_dir
    install_dir=${input_dir:-$install_dir}

    # 创建安装目录
    mkdir -p "$install_dir"/{elasticsearch/{data,logs,config},kibana/{config,data}}

    # 设置权限
    chmod 777 "$install_dir/elasticsearch/data" "$install_dir/elasticsearch/logs"
    chmod 777 "$install_dir/kibana/data"

    # 生成Elasticsearch配置
    cat > "$install_dir/elasticsearch/config/elasticsearch.yml" <<'EOF'
cluster.name: "elk-cluster"
node.name: "es-node-1"
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.monitoring.collection.enabled: true
EOF

    # 生成Kibana配置
    cat > "$install_dir/kibana/config/kibana.yml" <<'EOF'
server.name: kibana
server.host: 0.0.0.0
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
monitoring.ui.container.elasticsearch.enabled: true
i18n.locale: "zh-CN"
EOF

    # 生成docker-compose.yml
    cat > "$install_dir/docker-compose.yml" <<EOF
version: '3.8'

services:
  elasticsearch:
    image: elasticsearch:8.11.0
    restart: always
    container_name: elasticsearch
    networks:
      - elk-network
    ports:
      - "${es_port}:9200"
      - "9300:9300"
    environment:
      - "ES_JAVA_OPTS=-Xms${heap_size} -Xmx${heap_size}"
      - "discovery.type=single-node"
      - "xpack.security.enabled=false"
      - "cluster.name=elk-cluster"
    volumes:
      - ./elasticsearch/data:/usr/share/elasticsearch/data
      - ./elasticsearch/logs:/usr/share/elasticsearch/logs
      - ./elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  kibana:
    image: kibana:8.11.0
    restart: always
    container_name: kibana
    networks:
      - elk-network
    ports:
      - "${kibana_port}:5601"
    environment:
      ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
    volumes:
      - ./kibana/config/kibana.yml:/usr/share/kibana/config/kibana.yml
      - ./kibana/data:/usr/share/kibana/data
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  elk-network:
    driver: bridge
EOF

    # 启动服务
    if start_service "ELK Stack" "$install_dir" "elasticsearch"; then
        local local_ip
        local_ip=$(get_local_ip)
        log_info "ELK Stack 配置信息："
        log_info "  Elasticsearch:"
        log_info "    - 容器名: elasticsearch"
        log_info "    - HTTP 端口: ${es_port}:9200"
        log_info "    - 访问地址: http://${local_ip}:${es_port}"
        log_info "  Kibana:"
        log_info "    - 容器名: kibana"
        log_info "    - 端口: ${kibana_port}:5601"
        log_info "    - 访问地址: http://${local_ip}:${kibana_port}"
        log_info "  数据目录: $(realpath $install_dir)"
    fi
}

# ==================== 菜单和主程序 ====================

# 常用软件安装菜单
install_common_services() {
    while true; do
        clear
        echo
        echo "================ 常用服务安装脚本 v${SCRIPT_VERSION} ================"
        echo
        echo "🗄️  数据库服务:"
        echo "  1.  安装 Redis"
        echo "  2.  安装 MySQL"
        echo "  3.  安装 PostgreSQL"
        echo "  4.  安装 ClickHouse"
        echo "  5.  安装 Neo4j"
        echo
        echo "🔍 搜索和分析:"
        echo "  6.  安装 Elasticsearch"
        echo "  7.  安装 Kibana"
        echo "  8.  安装 ELK Stack (ES+Kibana)"
        echo
        echo "🌐 Web服务和存储:"
        echo "  9.  安装 Nginx"
        echo "  10. 安装 MinIO"
        echo
        echo "  0.  退出脚本"
        echo "================================================================"
        echo

        local choice
        read -rp "请选择要执行的操作 [0-10]: " choice

        case $choice in
            1) install_redis_service ;;
            2) install_mysql_service ;;
            3) install_postgresql_service ;;
            4) install_clickhouse_service ;;
            5) install_neo4j_service ;;
            6) install_elasticsearch_service ;;
            7) install_kibana_service ;;
            8) install_elk_stack ;;
            9) install_nginx_service ;;
            10) install_minio_service ;;
            0)
                log_info "感谢使用服务安装脚本，再见！"
                exit 0
                ;;
            *) log_error "无效选择，请输入 0-10 之间的数字" ;;
        esac

        echo
        log_info "按任意键继续..."
        read -r
    done
}

# ==================== 脚本入口点 ====================

# 捕获中断信号，优雅退出
trap 'log_warn "脚本被中断，正在清理..."; cd "$SCRIPT_START_DIR"; exit 130' INT TERM

# 脚本初始化
init_script() {
    # 设置严格模式
    set -euo pipefail

    # 检查系统要求
    if [[ $EUID -eq 0 ]]; then
        log_warn "检测到以root用户运行，建议使用普通用户"
        if ! confirm_action "是否继续？"; then
            exit 1
        fi
    fi

    # 检查系统内存
    local mem_total
    if [[ -f /proc/meminfo ]]; then
        mem_total=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
        if [[ $mem_total -lt 2 ]]; then
            log_warn "系统内存不足2GB，某些服务可能无法正常运行"
        fi
    fi

    # 检查磁盘空间
    local disk_avail
    disk_avail=$(df . | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_avail -lt 5 ]]; then
        log_warn "当前目录可用磁盘空间不足5GB"
        if ! confirm_action "是否继续？"; then
            exit 1
        fi
    fi
}

# 主程序入口
main() {
    # 显示脚本信息
    clear
    echo
    log_info "常用服务安装脚本 v${SCRIPT_VERSION} 启动"
    log_info "当前用户: $(whoami)"
    log_info "系统信息: $(uname -sr)"
    log_info "当前目录: $(pwd)"

    # 初始化脚本
    init_script

    # 检查Docker环境（非强制）
    if ! validate_docker_environment; then
        log_warn "Docker环境检查失败，部分功能可能无法使用"
        if ! confirm_action "是否继续？"; then
            exit 1
        fi
    fi

    echo
    log_info "环境检查完成，正在启动主菜单..."
    sleep 2

    # 启动主程序
    install_common_services
}

# 启动主程序
main "$@"