#!/usr/bin/env bash
# ==============================================================================
# 《格式塔》(Gestalt) - 一键 Web 端构建与调试启动脚本
# ==============================================================================

set -e

PORT=8060
USE_HTTPS=false
NO_EXPORT=false
RELEASE_MODE=false
NO_BROWSER=false

# 解析命令行参数
for arg in "$@"; do
    case "$arg" in
        --https)
            USE_HTTPS=true
            ;;
        --no-export)
            NO_EXPORT=true
            ;;
        --release)
            RELEASE_MODE=true
            ;;
        --no-browser)
            NO_BROWSER=true
            ;;
        --port=*)
            PORT="${arg#*=}"
            ;;
        [0-9]*)
            PORT="$arg"
            ;;
    esac
done

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"

# 查找 Godot 4 可执行文件路径
find_godot_binary() {
    if [ -n "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ]; then
        echo "$GODOT_BIN"
        return 0
    fi

    for cmd in godot godot4 godot-engine; do
        if command -v "$cmd" &> /dev/null; then
            command -v "$cmd"
            return 0
        fi
    done

    local candidate_paths=(
        "/dat/SteamLibrary/steamapps/common/Godot Engine/godot.x11.opt.tools.64"
        "$HOME/.local/bin/godot"
        "/home/ithea/.local/bin/godot"
        "/home/agy1/.gemini/antigravity-cli/bin/godot"
        "$PROJECT_DIR/bin/godot"
        "/usr/local/bin/godot"
        "/usr/bin/godot"
    )

    for p in "${candidate_paths[@]}"; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done

    return 1
}

if [ "$NO_EXPORT" = false ]; then
    echo "-------------------------------------------------------"
    echo "  [1/2] 正在检测 Godot 4 引擎路径..."
    echo "-------------------------------------------------------"

    GODOT_EXEC=$(find_godot_binary || true)

    if [ -z "$GODOT_EXEC" ]; then
        echo "❌ 未检测到 Godot 4 可执行文件！"
        echo "请尝试指定路径: GODOT_BIN=\"/path/to/godot\" ./start_web.sh"
        exit 1
    fi

    echo "✓ 已找到 Godot 引擎: $GODOT_EXEC"
    mkdir -p "$BUILD_DIR"

    EXPORT_FLAG="--export-debug"
    if [ "$RELEASE_MODE" = true ]; then
        EXPORT_FLAG="--export-release"
    fi

    echo "-------------------------------------------------------"
    echo "  正在执行 Godot Web 端工程构建导出 ($EXPORT_FLAG)..."
    echo "-------------------------------------------------------"

    "$GODOT_EXEC" --headless "$EXPORT_FLAG" "Web" "$BUILD_DIR/index.html"

    # 应用 Secure Context 与 AudioWorklet 兼容补丁
    python3 "$PROJECT_DIR/scripts/tools/patch_web.py" "$BUILD_DIR"

    echo "✓ Web 端工程导出构建完成！"
fi

echo "-------------------------------------------------------"
echo "  启动本地 Web 调试服务器..."
echo "-------------------------------------------------------"

SERVER_ARGS=(--dir "$BUILD_DIR" --port "$PORT")
if [ "$USE_HTTPS" = true ]; then
    SERVER_ARGS+=(--https)
fi
if [ "$NO_BROWSER" = true ]; then
    SERVER_ARGS+=(--no-browser)
fi

python3 "$PROJECT_DIR/scripts/tools/web_server.py" "${SERVER_ARGS[@]}"
