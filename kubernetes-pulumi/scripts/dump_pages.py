import asyncio
from playwright.async_api import async_playwright
import subprocess


def get_password():
    result = subprocess.run(
        [
            "doppler",
            "secrets",
            "get",
            "AUTHENTIK_BOOTSTRAP_PASSWORD",
            "--plain",
            "--project",
            "infrastructure",
            "--config",
            "prd",
        ],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


async def dump(url, name):
    password = get_password()
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(ignore_https_errors=True)
        page = await context.new_page()
        print(f"Loading {name}...")

        try:
            await page.goto(url)
            await page.wait_for_timeout(2000)

            if "auth.smadja.dev" in page.url or "outpost.goauthentik.io" in page.url:
                print(f"[Auth] Logging into Authentik for {name}")
                await page.fill('input[name="uidField"]', "akadmin")
                try:
                    await page.click('button[type="submit"]', timeout=3000)
                    await page.wait_for_timeout(1000)
                except Exception:
                    pass
                await page.fill('input[name="password"]', password)
                await page.click('button[type="submit"]')
                await page.wait_for_load_state("networkidle")
                await page.wait_for_timeout(3000)

            content = await page.evaluate("document.body.innerText")
            print(f"\n--- {name} TEXT ---")
            print(content[:1000])
            print("-------------------\n")
        except Exception as e:
            print(f"Error checking {name}: {e}")

        await browser.close()


async def main():
    await dump("https://music.smadja.dev", "Navidrome")
    await dump("https://ai.smadja.dev", "Open WebUI")


if __name__ == "__main__":
    asyncio.run(main())
