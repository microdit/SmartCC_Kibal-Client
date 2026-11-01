import process from "node:process";
import { Registerer, RegistererState, UserAgent } from "sip.js";

const domain = process.env.SIP_DOMAIN ?? "127.0.0.1";
const username = process.env.SIP_USERNAME ?? "1101";
const password = process.env.SIP_PASSWORD;
const server = process.env.SIP_WS_SERVER ?? `ws://${domain}:8088/ws`;
const timeoutMs = Number(process.env.SIP_TIMEOUT_MS ?? 15000);
const traceSip = process.env.SIP_TRACE === "1";

if (!password) {
  console.error("SIP_PASSWORD is required");
  process.exit(2);
}

const uri = UserAgent.makeURI(`sip:${username}@${domain}`);
if (!uri) {
  console.error(`invalid SIP URI: ${username}@${domain}`);
  process.exit(2);
}

const ua = new UserAgent({
  uri,
  authorizationUsername: username,
  authorizationPassword: password,
  displayName: `Kibal ${username}`,
  logLevel: "warn",
  logBuiltinEnabled: false,
  transportOptions: { server, traceSip },
  logConnector: (level, category, label, content) => {
    console.error(`[${level}] ${category}${label ? ` ${label}` : ""}: ${content}`);
  }
});

const registerer = new Registerer(ua);

let registeredResolve;
let registeredReject;
const registered = new Promise((resolve, reject) => {
  registeredResolve = resolve;
  registeredReject = reject;
});

registerer.stateChange.addListener((state) => {
  console.log(`registration state: ${state}`);
  if (state === RegistererState.Registered) {
    registeredResolve();
  } else if (state === RegistererState.Terminated) {
    registeredReject(new Error("registration terminated"));
  }
});

const timer = setTimeout(() => {
  registeredReject(new Error(`registration timed out after ${timeoutMs}ms`));
}, timeoutMs);

try {
  await ua.start();
  console.log(`transport connected: ${server}`);
  await registerer.register();
  await registered;
  console.log(`registered: ${username}@${domain}`);
  await registerer.unregister();
  await ua.stop();
  console.log("unregistered and stopped");
} catch (error) {
  console.error(`registration failed: ${error instanceof Error ? error.message : error}`);
  await ua.stop().catch(() => undefined);
  process.exitCode = 1;
} finally {
  clearTimeout(timer);
}
