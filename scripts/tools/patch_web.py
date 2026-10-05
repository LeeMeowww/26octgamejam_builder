#!/usr/bin/env python3
"""
Patch Godot 4 Web Export to eliminate:
1. 'Secure Context' blocking error on HTTP / LAN IP connections
2. 'Cannot read properties of undefined (reading addModule)' error when AudioWorklet is missing
"""

import sys
import os

def patch_web_export(web_dir):
    index_html = os.path.join(web_dir, "index.html")
    index_js = os.path.join(web_dir, "index.js")

    if not os.path.isfile(index_html):
        print(f"⚠️ 未找到 {index_html}，跳过补丁。")
        return False

    # -------------------------------------------------------------
    # 1. Patch index.html (Clean, minimal polyfill without wrapping AudioContext)
    # -------------------------------------------------------------
    with open(index_html, "r", encoding="utf-8") as f:
        html_content = f.read()

    # Polyfill isSecureContext
    poly = """<script>
		if (!window.isSecureContext) {
			try {
				Object.defineProperty(window, 'isSecureContext', { value: true, configurable: true, writable: true });
			} catch (e) {
				window.isSecureContext = true;
			}
		}
		</script>
		<script src="index.js"></script>"""

    if '<script src="index.js"></script>' in html_content and 'isSecureContext' not in html_content:
        html_content = html_content.replace('<script src="index.js"></script>', poly)

    old_missing = "const missing = Engine.getMissingFeatures({"
    new_missing = "let missing = Engine.getMissingFeatures({"
    if old_missing in html_content:
        html_content = html_content.replace(old_missing, new_missing)

    old_if = "if (missing.length !== 0) {"
    new_if = """if (!GODOT_THREADS_ENABLED) {
		missing = missing.filter(function(item) { return !item.includes('Secure Context'); });
	}
	if (missing.length !== 0) {"""
    if old_if in html_content and 'missing.filter' not in html_content:
        html_content = html_content.replace(old_if, new_if)

    with open(index_html, "w", encoding="utf-8") as f:
        f.write(html_content)

    print("✓ 已注入 index.html 兼容补丁 (SecureContext Polyfill)")

    # -------------------------------------------------------------
    # 2. Patch index.js (Safe AudioWorklet.addModule & Audio fallback)
    # -------------------------------------------------------------
    if os.path.isfile(index_js):
        with open(index_js, "r", encoding="utf-8") as f:
            js_content = f.read()

        # Call site 1: ctx.audioWorklet.addModule(path)
        c1_old = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);'
        c1_new = 'GodotAudio.audioPositionWorkletPromise=(ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve());'
        if c1_old in js_content:
            js_content = js_content.replace(c1_old, c1_new)

        # Call site 2: GodotAudioWorklet.promise=GodotAudio.ctx.audioWorklet.addModule(path).then(...)
        c2_old = 'GodotAudioWorklet.promise=GodotAudio.ctx.audioWorklet.addModule(path).then(function(){GodotAudioWorklet.worklet=new AudioWorkletNode(GodotAudio.ctx,"godot-processor",{outputChannelCount:[channels]});return Promise.resolve()});'
        c2_new = 'GodotAudioWorklet.promise=(GodotAudio.ctx&&GodotAudio.ctx.audioWorklet?GodotAudio.ctx.audioWorklet.addModule(path).then(function(){GodotAudioWorklet.worklet=new AudioWorkletNode(GodotAudio.ctx,"godot-processor",{outputChannelCount:[channels]});return Promise.resolve()}):Promise.resolve());'
        if c2_old in js_content:
            js_content = js_content.replace(c2_old, c2_new)

        with open(index_js, "w", encoding="utf-8") as f:
            f.write(js_content)
        print("✓ 已更新 index.js 防御性调用补丁 (Safe addModule & AudioWorklet fallback)")

    return True

if __name__ == "__main__":
    target_dir = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    if os.path.isfile(target_dir):
        target_dir = os.path.dirname(target_dir)
    patch_web_export(target_dir)
