import asyncio
import os
import subprocess
from playwright.async_api import async_playwright

apps_to_test = [
    {"name": "navidrome", "url": "https://music.smadja.dev"},
    {"name": "open-webui", "url": "https://ai.smadja.dev"},
    {"name": "opencloud", "url": "https://cloud.smadja.dev"},
    {"name": "audiobookshelf", "url": "https://audiobooks.smadja.dev"},
    {"name": "slskd", "url": "https://soulseek.smadja.dev"},
    {"name": "homepage", "url": "https://home.smadja.dev"},
]


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


async def run():
    password = get_password()
    if not password:
        print("Could not retrieve password from Doppler!")
        return

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        # We use a single context so we only log in once
        context = await browser.new_context(ignore_https_errors=True)
        page = await context.new_page()

        print("Testing connections and capturing screenshots...")
        os.makedirs("screenshots", exist_ok=True)

        for app in apps_to_test:
            print(f"Visiting {app['name']} at {app['url']}...")
            try:
                response = await page.goto(app["url"], wait_until="networkidle")
                await page.wait_for_timeout(2000)

                # Check if we landed on the Authentik login page
                if "if/flow" in page.url or "auth.smadja.dev" in page.url:
                    print("  [Auth] Detected Authentik login page for", app["name"])
                    await page.fill('input[name="uidField"]', "akadmin")

                    # Sometimes there's a next button before password
                    try:
                        await page.click('button[type="submit"]', timeout=3000)
                        await page.wait_for_timeout(1000)
                    except Exception:
                        pass

                    await page.fill('input[name="password"]', password)
                    await page.click('button[type="submit"]')
                    await page.wait_for_load_state("networkidle")
                    await page.wait_for_timeout(3000)  # Give app time to load
                    print("  [Auth] Login submitted, URL is now", page.url)

                screenshot_path = f"screenshots/{app['name']}_loggedin.png"
                await page.screenshot(path=screenshot_path)

                print(
                    f"  Result: Status {response.status if response else 'Unknown'}, Title: {await page.title()}"
                )
                print(f"  Screenshot saved to {screenshot_path}")
            except Exception as e:
                print(f"  Error visiting {app['name']}: {e}")

        await browser.close()


if __name__ == "__main__":
    asyncio.run(run())
