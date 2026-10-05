#!/usr/bin/env python3
"""
Gestalt (格式塔) - Web Debug Server
Provides an HTTP/HTTPS server with:
1. Cross-Origin-Opener-Policy (COOP) and Cross-Origin-Embedder-Policy (COEP)
2. Automatic SSL/HTTPS certificate generation for Secure Context
3. Proper MIME types for WebAssembly, PCK, and SVG
4. Disabled caching for live development
"""

import sys
import os
import argparse
import socket
import ssl
import subprocess
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler

class GodotWebHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory=None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self):
        # Critical headers for Godot 4 Web (SharedArrayBuffer and WASM threading / isolation)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        # Disable caching during debugging
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def guess_type(self, path):
        # Ensure correct MIME types for WebAssembly and Godot PCK
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".pck"):
            return "application/octet-stream"
        if path.endswith(".js"):
            return "application/javascript"
        if path.endswith(".svg"):
            return "image/svg+xml"
        if path.endswith(".json"):
            return "application/json"
        return super().guess_type(path)

    def log_message(self, format, *args):
        # Suppress verbose standard HTTP request logs unless error
        if len(args) > 1 and str(args[1]).startswith(('4', '5')):
            sys.stderr.write(f"[HTTP {args[1]}] {args[0]}\n")

def find_available_port(start_port=8060, max_attempts=50):
    for port in range(start_port, start_port + max_attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(('127.0.0.1', port)) != 0:
                return port
    return start_port

def generate_self_signed_cert(cert_dir):
    os.makedirs(cert_dir, exist_ok=True)
    cert_path = os.path.join(cert_dir, "cert.pem")
    key_path = os.path.join(cert_dir, "key.pem")
    if not (os.path.exists(cert_path) and os.path.exists(key_path)):
        try:
            subprocess.run([
                "openssl", "req", "-x509", "-newkey", "rsa:2048",
                "-keyout", key_path, "-out", cert_path,
                "-days", "365", "-nodes",
                "-subj", "/CN=localhost"
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"⚠️ 生成自签名证书失败: {e}")
            return None, None
    return cert_path, key_path

def run_server(web_dir, port=8060, use_https=False, open_browser=True):
    actual_port = find_available_port(port)
    handler = lambda *args, **kwargs: GodotWebHandler(*args, directory=web_dir, **kwargs)

    try:
        httpd = HTTPServer(('0.0.0.0', actual_port), handler)
    except Exception as e:
        print(f"❌ 启动 Web 服务器失败: {e}")
        return

    protocol = "http"
    if use_https:
        cert_dir = os.path.join(web_dir, ".ssl")
        cert_path, key_path = generate_self_signed_cert(cert_dir)
        if cert_path and key_path:
            try:
                ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                ssl_context.load_cert_chain(certfile=cert_path, keyfile=key_path)
                httpd.socket = ssl_context.wrap_socket(httpd.socket, server_side=True)
                protocol = "https"
            except Exception as e:
                print(f"⚠️ SSL 启用失败，回退至 HTTP 模式: {e}")
                protocol = "http"

    url = f"{protocol}://localhost:{actual_port}"
    print(f"\n=======================================================")
    print(f"  🌿《格式塔》(Gestalt) Web 端调试服务器已启动！")
    print(f"  🌐 访问地址: {url}")
    print(f"  📂 网页目录: {os.path.abspath(web_dir)}")
    print(f"  ⚙  模式: {protocol.upper()} (COOP/COEP 隔离标头已就绪)")
    if protocol == "https":
        print(f"  🔒 HTTPS 原生安全上下文 (Secure Context) 已激活")
    else:
        print(f"  💡 若通过局域网IP访问提示 Secure Context，可使用 --https 启动")
    print(f"  🛑 按 Ctrl + C 停止服务")
    print(f"=======================================================\n")

    if open_browser:
        try:
            webbrowser.open(url)
        except Exception:
            pass

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n正在关闭 Web 调试服务器...")
        httpd.server_close()
        print("✓ Web 服务器已安全退出。")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Gestalt Godot 4 Web Debug Server")
    parser.add_argument("--dir", default="build/web", help="Directory containing exported Web files")
    parser.add_argument("--port", type=int, default=8060, help="Port to serve on (default: 8060)")
    parser.add_argument("--https", action="store_true", help="Enable HTTPS with self-signed certificate")
    parser.add_argument("--no-browser", action="store_true", help="Do not automatically open browser")
    args = parser.parse_args()

    web_directory = os.path.abspath(args.dir)
    if not os.path.exists(web_directory):
        print(f"错误: 目录 {web_directory} 不存在，请先执行 Web 导出。")
        sys.exit(1)

    run_server(web_directory, args.port, args.https, not args.no_browser)
