import json
import sys
import os
import time
import random
import urllib.parse as urlparse

sys.stdout.reconfigure(encoding="utf-8")

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


def log(msg):
  print(msg)
  sys.stdout.flush()


def create_driver():
  options = webdriver.ChromeOptions()

  user_home = os.path.expanduser("~")
  profile_dir = os.path.join(user_home, "wa_sender_profile")
  os.makedirs(profile_dir, exist_ok=True)
  options.add_argument(f"--user-data-dir={profile_dir}")
  options.add_argument("--profile-directory=Default")

  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-background-timer-throttling")
  options.add_argument("--disable-backgrounding-occluded-windows")
  options.add_argument("--disable-renderer-backgrounding")
  options.add_argument("--disable-features=IsolateOrigins,site-per-process")
  options.add_experimental_option("excludeSwitches", ["enable-automation"])
  options.add_experimental_option("useAutomationExtension", False)

  driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
  )
  return driver


def send_text_message(driver, message_text):
  try:
    if not message_text.strip():
      return
    msg_box = WebDriverWait(driver, 30).until(
      EC.presence_of_element_located(
        (By.XPATH, "//div[@contenteditable='true' and @data-tab='10']")
      )
    )
    msg_box.click()
    time.sleep(0.3)
    msg_box.send_keys(message_text)
    time.sleep(0.3)
    msg_box.send_keys(Keys.ENTER)
  except Exception as e:
    log(f"❌ Failed to send text: {e}")


def send_attachments(driver, image_paths, doc_paths):

  def click_clip():
    selectors = [
      "//div[@role='button'][@aria-label='Attach']",
      "//span[@data-icon='clip']",
      "//button[@aria-label='Attach']",
    ]
    for s in selectors:
      try:
        btn = WebDriverWait(driver, 5).until(
          EC.element_to_be_clickable((By.XPATH, s))
        )
        btn.click()
        time.sleep(0.4)
        return True
      except Exception:
        pass
    log("⚠ Could not click clip button.")
    return False

  def click_send_media():
    selectors = [
      "//div[@aria-label='Send']",
      "//button[@aria-label='Send']",
      "//span[@data-icon='send']",
      "//*[contains(@data-icon,'send')]",
    ]
    for s in selectors:
      try:
        btn = WebDriverWait(driver, 8).until(
          EC.element_to_be_clickable((By.XPATH, s))
        )
        btn.click()
        time.sleep(0.5)
        return True
      except Exception:
        pass
    log("❌ Could not find media send button.")
    return False

  # IMAGES: send all in one message
  if image_paths:
    log(f"📷 Sending {len(image_paths)} image(s)...")
    if click_clip():
      try:
        img_input = WebDriverWait(driver, 8).until(
          EC.presence_of_element_located(
            (By.XPATH, "//input[@type='file' and contains(@accept,'image')]")
          )
        )
        img_input.send_keys("\n".join(image_paths))
        log("📤 Images uploaded. Waiting preview...")

        WebDriverWait(driver, 10).until(
          EC.presence_of_element_located(
            (By.XPATH, "//*[contains(@data-icon,'send')]")
          )
        )

        if click_send_media():
          log("✅ Images sent.")
        else:
          log("❌ Failed to send images.")
      except Exception as e:
        log(f"❌ Error sending images: {e}")

  # DOCUMENTS: send one per message
  for doc in doc_paths:
    log(f"📄 Sending document: {doc}")
    if not click_clip():
      log("❌ Failed to click clip for doc.")
      continue

    try:
      doc_input = WebDriverWait(driver, 8).until(
        EC.presence_of_element_located(
          (By.XPATH, "//input[@type='file']")
        )
      )
      doc_input.send_keys(doc)
      log("📤 Document uploaded. Waiting preview...")

      WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
          (By.XPATH, "//*[contains(@data-icon,'send')]")
        )
      )

      if click_send_media():
        log("✅ Document sent.")
      else:
        log("❌ Failed to send document.")
    except Exception as e:
      log(f"❌ Error sending doc: {e}")


def main():
  if len(sys.argv) < 2:
    log("❌ Usage: python sender.py config.json")
    sys.exit(1)

  config_path = sys.argv[1]

  with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

  contacts = cfg.get("contacts", [])
  message = cfg.get("message", "") or ""
  image_paths = cfg.get("image_paths", [])
  file_paths = cfg.get("file_paths", [])
  min_delay = float(cfg.get("min_delay", 2))
  max_delay = float(cfg.get("max_delay", 4))

  log(f"Loaded {len(contacts)} contacts.")
  log(f"Delay: {min_delay}s - {max_delay}s")

  try:
    driver = create_driver()
  except Exception as e:
    log(f"❌ Failed to launch Chrome: {e}")
    sys.exit(1)

  driver.get("https://web.whatsapp.com")
  log("➡ Waiting for WhatsApp Web login...")

  # Wait until either chat list or main pane appears
  try:
    WebDriverWait(driver, 300).until(
      EC.presence_of_element_located(
        (By.XPATH, "//div[@role='grid' or @aria-label='Chat list' or @id='app']")
      )
    )
    log("✅ WhatsApp Web UI loaded.")
  except Exception:
    log("⚠ Could not confirm login, continuing anyway...")

  for i, entry in enumerate(contacts, start=1):
    name = (entry.get("name") or "").strip()
    phone = (entry.get("number") or "").strip()

    if not phone:
      log("⚠ Skipping contact with empty number.")
      continue

    log(f"\n=== [{i}/{len(contacts)}] Sending to {phone} ({name}) ===")

    try:
      # Personalize message: {name}
      personal_msg = message
      if "{name}" in personal_msg:
        personal_msg = personal_msg.replace("{name}", name if name else "")

      encoded_msg = urlparse.quote(personal_msg)
      url = f"https://web.whatsapp.com/send?phone={phone}"
      driver.get(url)

      # Wait for chat input
      try:
        WebDriverWait(driver, 30).until(
          EC.presence_of_element_located(
            (By.XPATH, "//div[@contenteditable='true' and @data-tab='10']")
          )
        )
      except Exception:
        log(f"⚠ Chat not ready for {phone}, skipping.")
        continue

      # Send text if non-empty
      send_text_message(driver, personal_msg)

      # Send attachments
      send_attachments(driver, image_paths, file_paths)

      delay = random.uniform(min_delay, max_delay)
      log(f"✔ Done. Waiting {delay:.1f}s before next contact...")
      time.sleep(delay)

    except Exception as e:
      log(f"❌ Error sending to {phone}: {e}")
      time.sleep(random.uniform(2, 5))

  log("\n🎉 Finished sending to all contacts.")
  driver.quit()


if __name__ == "__main__":
  main()
