import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

// 6700 network-test always-on diagnostic bot.
// Uses a dedicated SIP account (7001) and feeds the WebRTC fake camera with a
// H.264-derived Y4M clip so that anyone joining 6700 immediately sees video.

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const domain = process.env.SIP_DOMAIN ?? "192.168.11.5";
const wsServer = process.env.SIP_WS_SERVER ?? `ws://${domain}:8088/ws`;
const ext = process.env.DIAG_EXT ?? "7001";
const room = process.env.DIAG_ROOM ?? "6700";
const previewPort = Number(process.env.PREVIEW_PORT ?? "4188");
const appUrl = `http://127.0.0.1:${previewPort}/`;
// 7001 봇 송출 콘텐츠: 원본 wiki/.../테스트영상_04_화사.mov →
// 배포용 파생 mp4(web/test-media)를 Client와 함께 배포하고, 실행 시
// ffmpeg로 Y4M(I420)/WAV를 생성해 Chrome 가상카메라/마이크에 주입한다.
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
// 원본 04화사.mov(1080p/23.6Mbps) → 1080p High 8Mbps 파생 mp4를 배포해 사용.
// GitHub 대용량 파일 제한(GH001)으로 원본 MOV는 커밋하지 않고 gitignore.
const MEDIA_SRC = path.join(ROOT, "test-media", "테스트영상_04_화사_webrtc_1080p30_60s.mp4");
const CACHE_DIR = path.join(ROOT, ".tmp", "diag-media");
const VIDEO_FILE = path.join(CACHE_DIR, "kibal_diag_feed_1920x1080.y4m");
const AUDIO_FILE = path.join(CACHE_DIR, "kibal_diag_feed_48k.wav");
const password = process.env[`SIP_PASSWORD_${ext}`];
const retryMs = Number(process.env.DIAG_RETRY_MS ?? "5000");
const holdCheckMs = Number(process.env.DIAG_HOLD_CHECK_MS ?? "3000");
const displayName = process.env.DIAG_DISPLAY_NAME ?? "AI봇";
const opsBase = process.env.OPS_BASE ?? `http://${domain}:8091`;
const opsKey = process.env.OPS_CLIENT_KEY ?? "dev-kibal-clients-2026";

if (!password) {
  console.error(`SIP_PASSWORD_${ext} is required (pass via env, do not commit)`);
  process.exit(2);
}
if (!existsSync(MEDIA_SRC)) {
  console.error(`media source missing: ${MEDIA_SRC}`);
  process.exit(2);
}

// execSync ffmpeg to build the Chrome-compatible fake capture files once.
function ensureMedia() {
  mkdirSync(CACHE_DIR, { recursive: true });
  if (!existsSync(VIDEO_FILE)) {
    console.log(`[${new Date().toISOString()}] generating Y4M from ${path.basename(MEDIA_SRC)} ...`);
    const r = spawnSync("ffmpeg", [
      "-y", "-i", MEDIA_SRC, "-t", "10",
      "-vf", "scale=1920:1080", "-r", "30", "-pix_fmt", "yuv420p",
      "-f", "yuv4mpegpipe", VIDEO_FILE,
    ], { encoding: "utf8" });
    if (r.status !== 0) throw new Error(`ffmpeg Y4M failed: ${r.stderr?.slice(-300)}`);
    // Chrome requires C420 (I420) header, ffmpeg emits C420jpeg.
    const buf = readFileSync(VIDEO_FILE);
    const nl = buf.indexOf(0x0a);
    const header = Buffer.from("YUV4MPEG2 W1920 H1080 F30:1 Ip A1:1 C420\n");
    writeFileSync(VIDEO_FILE, Buffer.concat([header, buf.subarray(nl + 1)]));
  }
  if (!existsSync(AUDIO_FILE)) {
    const r = spawnSync("ffmpeg", [
      "-y", "-i", MEDIA_SRC, "-t", "10", "-vn", "-ar", "48000", "-ac", "1",
      "-c:a", "pcm_s16le", AUDIO_FILE,
    ], { encoding: "utf8" });
    if (r.status !== 0) throw new Error(`ffmpeg WAV failed: ${r.stderr?.slice(-300)}`);
  }
  return { video: VIDEO_FILE, audio: AUDIO_FILE };
}

const browserArgs = [
  "--use-fake-ui-for-media-stream",
  "--use-fake-device-for-media-stream",
  "--autoplay-policy=no-user-gesture-required",
  "--disable-features=WebRtcHideLocalIpsWithMdns",
];

const preview = spawn("python3", ["-m", "http.server", String(previewPort), "--bind", "127.0.0.1", "--directory", "dist"], {
  cwd: process.cwd(),
  stdio: ["ignore", "pipe", "pipe"],
});
preview.on("error", (e) => console.error("preview spawn error:", e.message));

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

async function runOnce(browser) {
  const context = await browser.newContext({ permissions: ["camera", "microphone"], ignoreHTTPSErrors: true });
  const page = await context.newPage();
  try {
    await page.goto(appUrl);
    await page.locator("input").nth(0).fill(domain);
    await page.locator("input").nth(1).fill(wsServer);
    await page.locator("input").nth(2).fill(ext);
    await page.locator('input[type="password"]').fill(password);
    await page.getByRole("button", { name: /등록|다시 연결/ }).click();
    for (let i = 0; i < 60; i++) {
      const pill = await page.locator(".pill").innerText().catch(() => "");
      if (/등록됨/.test(pill)) break;
      await new Promise((r) => setTimeout(r, 500));
    }
    const pill = await page.locator(".pill").innerText().catch(() => "");
    if (!/등록됨/.test(pill)) throw new Error(`registration failed: ${pill}`);

    // OPS 참가자 카드에 "AI봇(7001)"으로 표시되도록 표시 이름 보고
    try {
      const res = await fetch(`${opsBase}/api/client/profile`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Client-Key": opsKey,
          "X-Client-Extension": ext,
        },
        body: JSON.stringify({ extension: ext, display_name: displayName, host: "diag-bot" }),
      });
      console.log(`[${new Date().toISOString()}] profile report ${ext}=${displayName}: HTTP ${res.status}`);
    } catch (e) {
      console.error(`profile report failed: ${e.message}`);
    }

    await page.locator('input[placeholder="내선 또는 6000"]').fill(room);
    await page.getByRole("button", { name: "호출", exact: true }).click();
    for (let i = 0; i < 60; i++) {
      const texts = await page.locator(".state").allInnerTexts().catch(() => []);
      if (texts.some((t) => t.includes("Established"))) break;
      const errs = await page.locator(".error").allInnerTexts().catch(() => []);
      if (errs.length) throw new Error(`call error: ${errs.join(" | ")}`);
      await new Promise((r) => setTimeout(r, 500));
    }
    const local = await page.evaluate(() => {
      const out = [];
      document.querySelectorAll("video").forEach((v) => {
        if (!v.srcObject) return;
        out.push(v.srcObject.getTracks().map((t) => ({
          kind: t.kind,
          state: t.readyState,
          w: t.getSettings?.().width ?? null,
          h: t.getSettings?.().height ?? null,
        })));
      });
      return out;
    });
    console.log(`[${new Date().toISOString()}] diag-bot ${ext} in ${room}: video=${JSON.stringify(local)}`);

    // Keep the session alive; monitor for transport drop.
    for (;;) {
      await new Promise((r) => setTimeout(r, holdCheckMs));
      const pillNow = await page.locator(".pill").innerText().catch(() => "");
      const stateTexts = await page.locator(".state").allInnerTexts().catch(() => []);
      if (!/등록됨/.test(pillNow) || !stateTexts.some((t) => t.includes("Established"))) {
        throw new Error("session lost (registration or call ended)");
      }
    }
  } finally {
    await context.close().catch(() => {});
  }
}

async function main() {
  const media = ensureMedia();
  console.log(`[${new Date().toISOString()}] diag media: ${media.video}`);
  const args = [
    ...browserArgs,
    `--use-file-for-fake-video-capture=${media.video}`,
    `--use-file-for-fake-audio-capture=${media.audio}`,
  ];
  await waitForServer(appUrl);
  const browser = await chromium.launch({ channel: "chrome", headless: true, args });
  for (;;) {
    try {
      await runOnce(browser);
    } catch (e) {
      console.error(`[${new Date().toISOString()}] diag-bot error: ${e.message}; retry in ${retryMs}ms`);
      await new Promise((r) => setTimeout(r, retryMs));
    }
  }
}

main().catch((e) => {
  console.error("fatal:", e);
  preview.kill("SIGTERM");
  process.exit(1);
});
