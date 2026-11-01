export interface SipConfig {
  username: string;
  password: string;
  domain: string;
  wsServer: string;
  displayName: string;
  iceServers: string[];
}

const env = import.meta.env;
const defaultDomain = env.VITE_SIP_DOMAIN ?? "192.168.11.2";
const defaultWsPort = env.VITE_SIP_WS_PORT ?? "8088";

export const defaultConfig: SipConfig = {
  username: env.VITE_SIP_USERNAME ?? "1101",
  password: env.VITE_SIP_PASSWORD ?? "",
  domain: defaultDomain,
  wsServer:
    env.VITE_SIP_WS_SERVER ?? `ws://${defaultDomain}:${defaultWsPort}/ws`,
  displayName: env.VITE_SIP_DISPLAY_NAME ?? "Kibal Web",
  iceServers: ["stun:stun.l.google.com:19302"]
};

const STORAGE_KEY = "kibal.sip.config";

export function loadStoredConfig(): SipConfig {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return defaultConfig;
    }
    const stored = JSON.parse(raw) as Partial<SipConfig>;
    return { ...defaultConfig, ...stored, password: defaultConfig.password };
  } catch {
    return defaultConfig;
  }
}

export function saveStoredConfig(config: SipConfig): void {
  const persisted = { ...config, password: "" };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(persisted));
}
