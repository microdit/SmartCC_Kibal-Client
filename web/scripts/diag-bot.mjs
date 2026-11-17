import { spawn } from "node:child_process";
import process from "node:process";
import { chromium } from "playwright";

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const domain = process.env.SIP_DOMAIN ?? "192.168.11.5";
const wsServer = process.env.SIP_WS_SERVER ?? `ws://${domain}:8088/ws`;
const ext = process.env.DIAG_EXT ?? "1101";
const room = process.env.DIAG_ROOM ?? "6700";
const holdMs = Number(process.env.DIAG_HOLD_MS ?? "20000");
const mode = process.env.DIAG_MODE ?? "sender";
const previewPort = Number(process.env.PREVIEW_PORT ?? "4188");
const appUrl = `http://127.0.0.1:${previewPort}/`;
const screenshotDir = process.env.SCREENSHOT_DIR ?? "/tmp";
const videoFile = process.env.DIAG_VIDEO_FILE ?? "";
const audioFile = process.env.DIAG_AUDIO_FILE ?? "";
const password = process.env[`SIP_PASSWORD_${ext}`];

if (!/^ws:\/\//.test(wsServer) && !/^wss:\/\//.test(wsServer)) {
  console.error("SIP_WS_SERVER must be ws:// or wss://");
  process.exit(2);
}
if (!password) {
  console.error(`SIP_PASSWORD_${ext} is required (pass via env, do not commit)`);
  process.exit(2);
}
if (mode === "sender" && !videoFile) {
  console.error("DIAG_VIDEO_FILE is required for sender");
  process.exit(2);
}

const browserArgs = [
  "--use-fake-ui-for-media-stream",
  "--use-fake-device-for-media-stream",
  "--autoplay-policy=no-user-gesture-required",
  "--disable-features=WebRtcHideLocalIpsWithMdns",
];
if (videoFile) browserArgs.push(`--use-file-for-fake-video-capture=${videoFile}`);
if (audioFile) browserArgs.push(`--use-file-for-fake-audio-capture=${audioFile}`);

const preview = spawn("python3", ["-m", "http.server", String(previewPort), "--bind", "127.0.0.1", "--directory", "dist"], {
  cwd: process.cwd(),
  stdio: ["ignore", "pipe", "pipe"],
});
preview.stdout.on("data", (c) => process.stderr.write(c));
preview.stderr.on("data", (c) => process.stderr.write(c));

let browser;
try {
  await waitForServer(appUrl);
  browser = await chromium.launch({ channel: "chrome", headless: true, args: browserArgs });
  const context = await browser.newContext({ permissions: ["camera", "microphone"], ignoreHTTPSErrors: true });
  const page = await context.newPage();
  page.on("console", (m) => {
    if (/error|warn/i.test(m.type())) console.error(`[browser:${m.type()}] ${m.text()}`);
  });

  await page.goto(appUrl);
  await page.locator("input").nth(0).fill(domain);
  await page.locator("input").nth(1).fill(wsServer);
  await page.locator("input").nth(2).fill(ext);
  await page.locator('input[type="password"]').fill(password);
  await page.getByRole("button", { name: /등록|다시 연결/ }).click();
  await waitForRegistered(page);
  console.log(`diag-bot registered: ${ext} (mode=${mode})`);

  await page.locator('input[placeholder="내선 또는 6000"]').fill(room);
  await page.getByRole("button", { name: "호출", exact: true }).click();
  await waitForState(page, "Established");
  console.log(`diag-bot joined room: ${room}`);

  await new Promise((r) => setTimeout(r, holdMs));
  const media = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll("video").forEach((v) => {
      if (!v.srcObject) return;
      const tracks = v.srcObject.getTracks().map((t) => ({
        kind: t.kind,
        state: t.readyState,
        w: t.getSettings?.().width ?? null,
        h: t.getSettings?.().height ?? null,
      }));
      out.push({ label: v.parentElement?.textContent?.trim() ?? "", tracks });
    });
    return out;
  });
  console.log("diag-bot media:", JSON.stringify(media));
  await page.screenshot({ path: `${screenshotDir}/kibal-diag-bot-${ext}-${mode}.png`, fullPage: true });

  await page.getByRole("button", { name: "통화 종료", exact: true }).click();
  await new Promise((r) => setTimeout(r, 1500));
  console.log("diag-bot done");
  await context.close();
} finally {
  if (browser) await browser.close();
  preview.kill("SIGTERM");
}

async function waitForServer(url) {
  for (let i = 0; i < 60; i++) {
    try {
      const r = await fetch(url);
      if (r.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`preview server not ready: ${url}`);
}

async function waitForRegistered(page) {
  for (let i = 0; i < 60; i++) {
    const pill = await page.locator(".pill").innerText().catch(() => "");
    if (/등록됨/.test(pill)) return;
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error("registration timeout");
}

async function waitForState(page, state) {
  for (let i = 0; i < 60; i++) {
    const texts = await page.locator(".state").allInnerTexts().catch(() => []);
    const errs = await page.locator(".error").allInnerTexts().catch(() => []);
    if (texts.some((t) => t.includes(state))) return;
    if (errs.length) throw new Error(`call error: ${errs.join(" | ")}`);
    await new Promise((r) => setTimeout(r, 500));
  }
  const texts = await page.locator(".state").allInnerTexts().catch(() => []);
  throw new Error(`state timeout: ${state}; states=${JSON.stringify(texts)}`);
}
