#!/usr/bin/env python3
import socket
import sys


# -------------------- TCP --------------------
def tcp_server(port: int):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("0.0.0.0", port))
    sock.listen(1)
    print(f"[TCP] Listening on 0.0.0.0:{port} ...")
    while True:
        conn, addr = sock.accept()
        print(f"[TCP] Connection from {addr}")
        data = conn.recv(1024)
        if data:
            text = data.decode(errors="ignore")
            print(f"[TCP] Received: {text}")
            conn.sendall(b"pong")
        conn.close()


def tcp_client(host: str, port: int, message: str):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.settimeout(3)
        sock.connect((host, port))
        print(f"[TCP] Connected to {host}:{port}")
        sock.sendall(message.encode())
        print(f"[TCP] Sent: {message}")
        sock.settimeout(2)
        data = sock.recv(1024)
        if data:
            print(f"[TCP] Received reply: {data.decode(errors='ignore')}")
        else:
            print("[TCP] No reply (connection closed).")
    except (socket.timeout, ConnectionRefusedError) as e:
        print(f"[TCP] Connection failed: {e}")
    finally:
        sock.close()


# -------------------- UDP --------------------
def udp_server(port: int):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", port))
    print(f"[UDP] Listening on 0.0.0.0:{port} ...")
    while True:
        data, addr = sock.recvfrom(1024)
        print(f"[UDP] Received from {addr}: {data.decode(errors='ignore')}")
        sock.sendto(b"pong", addr)


def udp_client(host: str, port: int, message: str):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(message.encode(), (host, port))
        print(f"[UDP] Sent to {host}:{port} -> {message}")
        sock.settimeout(2)
        data, addr = sock.recvfrom(1024)
        print(f"[UDP] Received reply from {addr}: {data.decode(errors='ignore')}")
    except socket.timeout:
        print("[UDP] No response (server may not reply or UDP blocked).")
    finally:
        sock.close()


# -------------------- 主函数 --------------------
def main():
    if len(sys.argv) < 4:
        print("用法:")
        print("  TCP服务器: python3 net_tool.py tcp server <port>")
        print("  TCP客户端: python3 net_tool.py tcp client <host> <port> [message]")
        print("  UDP服务器: python3 net_tool.py udp server <port>")
        print("  UDP客户端: python3 net_tool.py udp client <host> <port> [message]")
        sys.exit(1)

    proto = sys.argv[1].lower()
    mode = sys.argv[2].lower()

    if proto == "tcp":
        if mode == "server":
            port = int(sys.argv[3])
            tcp_server(port)
        elif mode == "client":
            host = sys.argv[3]
            port = int(sys.argv[4])
            message = sys.argv[5] if len(sys.argv) > 5 else "hello tcp"
            tcp_client(host, port, message)
        else:
            print("模式错误，只能是 server 或 client")
    elif proto == "udp":
        if mode == "server":
            port = int(sys.argv[3])
            udp_server(port)
        elif mode == "client":
            host = sys.argv[3]
            port = int(sys.argv[4])
            message = sys.argv[5] if len(sys.argv) > 5 else "hello udp"
            udp_client(host, port, message)
        else:
            print("模式错误，只能是 server 或 client")
    else:
        print("协议错误，只能是 tcp 或 udp")


if __name__ == "__main__":
    main()
