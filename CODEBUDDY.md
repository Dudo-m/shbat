# CODEBUDDY.md

This repository contains AI-generated shell scripts for system administration and service deployment. The scripts are designed to be run on Linux systems (primarily CentOS/RHEL and Ubuntu/Debian).

## Repository Structure

Scripts are organized into categorized folders:

### `/docker/`
- `docker-centos.sh` - CentOS/RHEL/Fedora Docker management script (v4.1.1)
- `docker-ubuntu.sh` - Ubuntu/Debian Docker management script  
- `docker_services.sh` - Service installation script for common applications (Redis, MySQL, PostgreSQL, Nginx, Elasticsearch, etc.)

### `/email/`
- `email-centos.sh` - CentOS email server configuration script for Postfix and Dovecot

### `/vpn/`
- `vpn-centos.sh` - CentOS/RHEL/Fedora optimized VPN script

## Common Usage Patterns

### Running Scripts
All scripts require root privileges and should be executed with:
```bash
sudo bash script_name.sh
```

### Remote Execution
The scripts are designed to be executed remotely via curl:

**GitHub:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/folder/script_name.sh)
```

**Gitee (China mirror):**
```bash
bash <(curl -Ls https://gitee.com/LI_li_plus/shbat/raw/master/folder/script_name.sh)
```

**Examples:**
```bash
# Docker management (CentOS)
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker-centos.sh)

# Docker services installation
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/docker/docker_services.sh)

# VPN for CentOS
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/vpn/vpn-centos.sh)

# Email server
bash <(curl -Ls https://raw.githubusercontent.com/Dudo-m/shbat/refs/heads/master/email/email-centos.sh)
```

## Script Architecture

### Docker Management Scripts
- **`docker-centos.sh`** (v4.1.1) - CentOS/RHEL/Fedora Docker management
- **`docker-ubuntu.sh`** - Ubuntu/Debian Docker management
- **Features**: Interactive menu system, Docker installation/uninstallation, container management, image operations, mirror configuration
- **Key Functions**:
  - `install_docker()` - Supports both official and Chinese mirror sources
  - `configure_docker_mirror()` - Sets up Docker registry mirrors with fallback mirrors
  - `export_selected_images()` / `import_images_from_dir()` - Image backup/restore
  - Container lifecycle management with interactive selection
- **Mirror Sources**: Includes 8+ Chinese Docker registry mirrors for improved connectivity

### Service Installation (`docker/docker_services.sh`)
- **Version**: 2.0.0
- **Services Supported**: Redis, MySQL, PostgreSQL, ClickHouse, Neo4j, Elasticsearch, Kibana, Nginx, MinIO
- **Architecture**: 
  - Uses Docker Compose for service orchestration
  - Generates configuration files dynamically based on user input
  - Creates isolated networks for services
  - Includes health checks and proper volume mounting

### Email Server (`email/email-centos.sh`)
- **Target**: CentOS systems
- **Components**: Postfix (SMTP) + Dovecot (POP3/IMAP)
- **Features**: Domain configuration, user management, firewall setup

### VPN Services
- **`vpn/vpn-centos.sh`** - CentOS/RHEL/Fedora optimized version using firewalld and yum
- **Protocols**: PPTP, L2TP/IPsec, OpenVPN
- **Features**: Automatic firewall configuration, certificate management for OpenVPN, system-specific optimizations

## Key Design Patterns

### Error Handling
- Scripts use `set -euo pipefail` for strict error handling
- Comprehensive logging with colored output functions
- Backup creation before modifying system configurations

### User Interaction
- Interactive menus with input validation
- Confirmation prompts for destructive operations
- Automatic password generation with user override options

### System Compatibility
- OS detection and package manager adaptation
- Firewall type detection (firewalld, ufw, iptables)
- Network interface auto-detection

### Configuration Management
- Template-based configuration file generation
- Environment-specific parameter substitution
- Backup and restore capabilities for system configurations

## Development Notes

- Scripts are written in Bash with POSIX compliance where possible
- Chinese comments and messages indicate target audience (Chinese users)
- Heavy use of heredocs for configuration file templates
- Modular function design with clear separation of concerns
- Network and security configurations are environment-aware
- All scripts include comprehensive logging with colored output
- Automatic network interface detection and IP address resolution
- Cross-platform compatibility (supports both systemd and traditional init systems)

## Testing and Validation

Since these are system administration scripts that require root privileges and modify system configurations:

- **Testing Environment**: Use virtual machines or containers for testing
- **Validation**: Scripts include built-in system compatibility checks
- **Rollback**: Most scripts create backups before making changes
- **Prerequisites**: All scripts check for root privileges and system compatibility before execution

## Common Development Tasks

- **Adding New Services**: Follow the pattern in `docker_services.sh` with Docker Compose templates
- **OS Support**: Create separate scripts for different distributions (CentOS vs Ubuntu patterns)
- **Firewall Rules**: Use distribution-specific firewall tools (firewalld for RHEL/CentOS, ufw for Ubuntu)
- **Configuration Templates**: Use heredocs for generating config files with variable substitution

## Security Considerations

- All scripts require root privileges
- Firewall rules are automatically configured
- SSL/TLS certificates are generated for applicable services
- Default passwords are randomly generated
- Services are configured with security best practices (where applicable)