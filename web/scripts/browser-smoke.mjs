import { spawn } from "node:child_process";
import process from "node:process";
import { chromium } from "playwright";

const domain = process.env.SIP_DOMAIN ?? "127.0.0.1";
const wsServer = process.env.SIP_WS_SERVER ?? `ws://${domain}:8088/ws`;
const password1101 = process.env.SIP_PASSWORD_1101;
const password1102 = process.env.SIP_PASSWORD_1102;
const password1103 = process.env.SIP_PASSWORD_1103;
const runCall = process.env.SIP_CALL === "1";
const runRoom = process.env.SIP_ROOM === "1";
const roomThird = process.env.SIP_ROOM_THIRD === "1";
const previewPort = Number(process.env.PREVIEW_PORT ?? 4173);
const appUrl = `http://127.0.0.1:${previewPort}/`;
const screenshotDir = process.env.SCREENSHOT_DIR ?? "/tmp";

if (!password1101) {
  console.error("SIP_PASSWORD_1101 is required");
  process.exit(2);
}
if ((runCall || runRoom) && !password1102) {
  console.error("SIP_PASSWORD_1102 is required when SIP_CALL=1 or SIP_ROOM=1");
  process.exit(2);
}
if (roomThird && !password1103) {
  console.error("SIP_PASSWORD_1103 is required when SIP_ROOM_THIRD=1");
  process.exit(2);
}

const preview = spawn(
  "npm",
  ["run", "preview", "--", "--port", String(previewPort), "--strictPort"],
  { stdio: ["ignore", "pipe", "pipe"] }
);

preview.stdout.on("data", (chunk) => process.stderr.write(chunk));
preview.stderr.on("data", (chunk) => process.stderr.write(chunk));

let browser;

try {
  await waitForServer(appUrl);
  browser = await chromium.launch({
    channel: "chrome",
    headless: true,
    args: [
      "--use-fake-ui-for-media-stream",
      "--use-fake-device-for-media-stream",
      "--autoplay-policy=no-user-gesture-required",
      "--disable-features=WebRtcHideLocalIpsWithMdns"
    ]
  });

  const user1101 = await openClient(browser, "1101", password1101);
  await register(user1101.page, "1101", password1101);
  console.log("browser registration ok: 1101");
  await user1101.page.screenshot({ path: `${screenshotDir}/kibal-register-1101.png`, fullPage: true });

  if (!runCall && !runRoom) {
    await unregister(user1101.page);
    await user1101.context.close();
  } else {
    const user1102 = await openClient(browser, "1102", password1102);
    await register(user1102.page, "1102", password1102);
    console.log("browser registration ok: 1102");

    if (runRoom) {
      await user1101.page.getByRole("button", { name: "회의실 6000 참가", exact: true }).click();
      await waitForState(user1101.page, "Established");
      console.log("conference joined: 1101");

      await user1102.page.getByRole("button", { name: "회의실 6000 참가", exact: true }).click();
      await waitForState(user1102.page, "Established");
      console.log("conference joined: 1102");

      let user1103;
      if (roomThird) {
        user1103 = await openClient(browser, "1103", password1103);
        await register(user1103.page, "1103", password1103);
        await user1103.page.getByRole("button", { name: "회의실 6000 참가", exact: true }).click();
        await waitForState(user1103.page, "Established");
        console.log("conference joined: 1103");
      }

      await new Promise((resolve) => setTimeout(resolve, 8000));
      await logMedia("1101", user1101.page);
      await logMedia("1102", user1102.page);
      if (user1103) {
        await logMedia("1103", user1103.page);
      }

      await user1101.page.screenshot({ path: `${screenshotDir}/kibal-room-1101.png`, fullPage: true });
      await user1102.page.screenshot({ path: `${screenshotDir}/kibal-room-1102.png`, fullPage: true });
      if (user1103) {
        await user1103.page.screenshot({ path: `${screenshotDir}/kibal-room-1103.png`, fullPage: true });
      }

      await user1101.page.getByRole("button", { name: "통화 종료", exact: true }).click();
      await user1102.page.getByRole("button", { name: "통화 종료", exact: true }).click();
      if (user1103) {
        await user1103.page.getByRole("button", { name: "통화 종료", exact: true }).click();
      }
      await new Promise((resolve) => setTimeout(resolve, 2000));
      if (user1103) {
        await unregister(user1103.page);
        await user1103.context.close();
      }
    } else {
      await user1101.page.locator('input[placeholder="내선 또는 6000"]').fill("1102");
      await user1101.page.getByRole("button", { name: "호출", exact: true }).click();

      await new Promise((resolve) => setTimeout(resolve, 2000));
      console.log(`caller state: ${await user1101.page.locator(".state").innerText()}`);
      const callerError = user1101.page.locator(".error");
      if ((await callerError.count()) > 0) {
        console.log(`caller error: ${await callerError.innerText()}`);
      }

      await user1102.page.getByRole("button", { name: "받기", exact: true }).waitFor({ timeout: 30000 });
      await user1102.page.getByRole("button", { name: "받기", exact: true }).click();

      await waitForState(user1101.page, "Established");
      await waitForState(user1102.page, "Established");
      console.log("call established: 1101 <-> 1102");

      await new Promise((resolve) => setTimeout(resolve, 3000));
      await logMedia("1101", user1101.page);
      await logMedia("1102", user1102.page);

      await user1101.page.screenshot({ path: `${screenshotDir}/kibal-call-1101.png`, fullPage: true });
      await user1102.page.screenshot({ path: `${screenshotDir}/kibal-call-1102.png`, fullPage: true });

      await user1101.page.getByRole("button", { name: "통화 종료", exact: true }).click();
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }

    await unregister(user1101.page);
    await unregister(user1102.page);
    await user1101.context.close();
    await user1102.context.close();
  }
} catch (error) {
  console.error(error instanceof Error ? error.stack ?? error.message : error);
  process.exitCode = 1;
} finally {
  await browser?.close().catch(() => undefined);
  preview.kill("SIGTERM");
}

async function openClient(browser, username, password) {
  const context = await browser.newContext({
    permissions: ["camera", "microphone"]
  });
  const page = await context.newPage();
  page.on("pageerror", (error) => console.error(`[page:${username}] ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      console.error(`[console:${username}] ${message.text()}`);
    }
  });
  await page.goto(`${appUrl}?debug=1`);
  await page.getByLabel("비밀번호").fill(password);
  return { context, page };
}

async function register(page, username, password) {
  await page.getByLabel("서버 도메인").fill(domain);
  await page.getByLabel("WebSocket URL").fill(wsServer);
  await page.getByLabel("내선").fill(username);
  await page.getByLabel("비밀번호").fill(password);
  await page.getByLabel("STUN/TURN (쉼표 구분)").fill(process.env.SIP_ICE_SERVERS ?? "");
  await page.getByRole("button", { name: "등록", exact: true }).click();
  await page.locator(".pill").filter({ hasText: "등록됨" }).waitFor({ timeout: 30000 });
  const error = await page.locator(".error").count();
  if (error > 0) {
    throw new Error(await page.locator(".error").innerText());
  }
}

async function unregister(page) {
  await page.getByRole("button", { name: "등록 해제", exact: true }).click();
  await page.locator(".pill").filter({ hasText: "미등록" }).waitFor({ timeout: 15000 });
  console.log("browser unregister ok");
}

async function waitForState(page, state) {
  await page.locator(".state").filter({ hasText: state }).waitFor({ timeout: 30000 });
}

async function logMedia(username, page) {
  console.log(`${username} remote elements: ${await page.locator(".video.remote video").count()}`);
  console.log(`${username} remote videos: ${JSON.stringify(await remoteVideoStats(page))}`);
  console.log(`${username} local video:   ${JSON.stringify(await localVideoStats(page))}`);
  console.log(`${username} peer stats:    ${JSON.stringify(await peerStats(page))}`);
}

async function remoteVideoStats(page) {
  return page.locator(".video.remote video").evaluateAll((videos) =>
    videos.map((video) => {
      const stream = video.srcObject;
      return {
        readyState: video.readyState,
        width: video.videoWidth,
        height: video.videoHeight,
        hasStream: Boolean(stream),
        paused: video.paused,
        tracks: stream instanceof MediaStream
          ? stream.getTracks().map((track) => ({
              kind: track.kind,
              readyState: track.readyState,
              muted: track.muted
            }))
          : []
      };
    })
  );
}

async function localVideoStats(page) {
  return page.locator(".video.local video").evaluate((video) => {
    const stream = video.srcObject;
    return {
      readyState: video.readyState,
      width: video.videoWidth,
      height: video.videoHeight,
      hasStream: Boolean(stream),
      paused: video.paused,
      tracks: stream instanceof MediaStream
        ? stream.getTracks().map((track) => ({
            kind: track.kind,
            readyState: track.readyState,
            muted: track.muted
          }))
        : []
    };
  });
}

async function peerStats(page) {
  return page.evaluate(async () => {
    const pc = window.__kibalPC;
    if (!pc) {
      return null;
    }
    const reports = [...(await pc.getStats()).values()];
    return {
      connectionState: pc.connectionState,
      iceConnectionState: pc.iceConnectionState,
      iceGatheringState: pc.iceGatheringState,
      remoteTracks: pc.getReceivers().map((receiver) => ({
        kind: receiver.track?.kind,
        muted: receiver.track?.muted
      })),
      succeededPairs: reports
        .filter((report) => report.type === "candidate-pair" && report.state === "succeeded")
        .map((report) => ({
          local: report.localCandidateId,
          remote: report.remoteCandidateId,
          bytesReceived: report.bytesReceived,
          bytesSent: report.bytesSent
        })),
      inbound: reports
        .filter((report) => report.type === "inbound-rtp")
        .map((report) => ({
          kind: report.kind,
          packets: report.packetsReceived,
          bytes: report.bytesReceived,
          frames: report.framesDecoded,
          width: report.frameWidth,
          height: report.frameHeight,
          audioLevel: report.audioLevel
        })),
      outbound: reports
        .filter((report) => report.type === "outbound-rtp")
        .map((report) => ({
          kind: report.kind,
          packets: report.packetsSent,
          bytes: report.bytesSent,
          frames: report.framesEncoded
        }))
    };
  });
}

async function waitForServer(url) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return;
      }
    } catch {
      // server not ready
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`preview server did not start: ${url}`);
}
