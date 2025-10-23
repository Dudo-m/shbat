# gs-netcat 使用说明（不含二进制）

- 上游项目与下载：https://github.com/hackerschoice/gsocket/releases
- 本目录仅提供使用说明，不包含 `gs-netcat` 二进制，请先从上游下载并放到当前目录。

## 准备工作

```bash
# 赋予执行权限（下载后）
chmod +x ./gs-netcat
```

## 生成共享密钥

```bash
./gs-netcat -g
```
将输出保存为后续命令的 `-s` 参数（如：`-s <SECRET>`）。

## 服务端示例

```bash
# 后台监听（示例端口 10001，请替换为你的端口与 SECRET）
./gs-netcat -l -D -s <SECRET> -p 10001
```

## 客户端示例

```bash
# 连接到服务端（确保与服务端使用相同的 SECRET 与端口）
./gs-netcat -D -s <SECRET> -p 10001
```

## 排查与日志

```bash
ps -ef | grep gs-netcat   # 进程查看
# 按系统查看日志，例如：
tail -f /var/log/syslog
```

## 注意事项

- 二进制务必从上游 Releases 获取，勿使用不可信来源。
- 部署前先在非生产环境验证参数与网络连通性。
- 如需长期运行，建议配合 systemd 或进程守护工具。

