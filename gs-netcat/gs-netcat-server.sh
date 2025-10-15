#!/bin/bash
# https://github.com/hackerschoice/gsocket
chmod +x gs-netcat

# 生成密钥
./gs-netcat -g

ps -ef | grep gs-netcat
#服务端
./gs-netcat -l -D -s xx -p 10001

#客户端
./gs-netcat -D -s xx -p 10001
