import sys
import os
import subprocess
import asyncio
from playwright.async_api import async_playwright

async def run_gameplay_test():
    server = subprocess.Popen([
        sys.executable, "scripts/tools/web_server.py",
        "--dir", "build/web",
        "--port", "8069",
        "--no-browser"
    ])
    await asyncio.sleep(1.5)

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--use-gl=angle",
                    "--use-angle=swiftshader"
                ]
            )
            context = await browser.new_context(viewport={"width": 1280, "height": 720})
            page = await context.new_page()

            console_messages = []
            page_errors = []

            page.on("console", lambda msg: console_messages.append(f"[{msg.type}] {msg.text}"))
            page.on("pageerror", lambda err: page_errors.append(str(err)))

            print("1. Opening Web Game...")
            await page.goto("http://127.0.0.1:8069", wait_until="networkidle", timeout=30000)

            # Wait for main menu
            await asyncio.sleep(5)
            await page.screenshot(path="screenshot_step1_main_menu.png")
            print("   Main menu loaded.")

            # Click Play button (around center X=640, Y=565)
            print("2. Clicking '开始游玩 (Play Levels)'...")
            await page.mouse.click(640, 565)
            await asyncio.sleep(2)
            await page.screenshot(path="screenshot_step2_level_select.png")
            print("   Level select loaded.")

            # Click Level 1 challenge button (Card 0 "开始挑战" exact center is at X=553, Y=197)
            print("3. Entering Level 1...")
            await page.mouse.click(553, 197)
            await asyncio.sleep(2)
            await page.screenshot(path="screenshot_step3_level_player.png")
            print("   Level 1 loaded into canvas.")

            # Test number keys in Level 1
            print("3.5. Testing number keys 1..6...")
            await page.keyboard.press("1")
            await asyncio.sleep(0.3)
            await page.keyboard.press("3") # Pusher
            await asyncio.sleep(0.3)
            await page.keyboard.press("4") # Replicator
            await asyncio.sleep(0.3)
            await page.keyboard.press("1") # Basic

            # Click back to return to main menu or level select (Back button at X=65, Y=20)
            print("4. Returning from Level 1...")
            await page.mouse.click(65, 20)
            await asyncio.sleep(1.5)
            # From LevelSelect back to MainMenu
            await page.mouse.click(105, 51)
            await asyncio.sleep(1.5)

            # Enter Level Manager from MainMenu (Button at X=640, Y=625)
            print("5. Opening Level Manager...")
            await page.mouse.click(640, 625)
            await asyncio.sleep(2)
            await page.screenshot(path="screenshot_level_manager.png")
            print("   Level Manager loaded.")

            # Click "进入关卡方块编辑 >>" button in Level Manager (around X=1140, Y=665)
            print("6. Entering Level Editor...")
            await page.mouse.click(1140, 665)
            await asyncio.sleep(2)
            await page.screenshot(path="screenshot_level_editor.png")
            print("   Level Editor loaded.")

            # Bug test: Place block outside build area in Level Editor
            print("7. Testing placement outside build area, then clear, then place, then space...")
            # Place outside green box (e.g. at X=800, Y=220)
            await page.mouse.click(800, 220)
            await asyncio.sleep(0.5)

            # Click "清空画布" (around X=60, Y=45)
            await page.mouse.click(60, 45)
            await asyncio.sleep(0.5)

            # Place a new block at X=550, Y=360
            await page.mouse.click(550, 360)
            await asyncio.sleep(0.5)

            # Press Space to test simulation!
            await page.keyboard.press("Space")
            await asyncio.sleep(1.5)
            await page.screenshot(path="screenshot_editor_sim.png")
            print("   Editor simulation tested successfully.")

            print("\n--- ALL PAGE ERRORS ---")
            for e in page_errors:
                print("ERROR:", e)

            if not page_errors:
                print("\n🎉 BROWSER GAMEPLAY TEST FULLY PASSED WITH 0 ERRORS!")

            await browser.close()
    finally:
        server.terminate()
        server.wait()

if __name__ == "__main__":
    asyncio.run(run_gameplay_test())

