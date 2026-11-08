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
  password: "",
  domain: defaultDomain,
  wsServer:
    env.VITE_SIP_WS_SERVER ?? `ws://${defaultDomain}:${defaultWsPort}/ws`,
  displayName: env.VITE_SIP_DISPLAY_NAME ?? "Kibal Web",
  iceServers: ["stun:stun.l.google.com:19302"]
};

const STORAGE_KEY = "kibal.sip.config";
const USERNAME_PATTERN = /^[0-9A-Za-z_.-]{1,32}$/;
const DOMAIN_PATTERN = /^[0-9A-Za-z.-]+(?::[0-9]{1,5})?$/;

export interface SipConfigValidation {
  config: SipConfig;
  errors: string[];
  warnings: string[];
}

export function normalizeWsServer(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "ws:" && parsed.protocol !== "wss:") {
      return trimmed;
    }
    if (!parsed.pathname || parsed.pathname === "/") {
      parsed.pathname = "/ws";
    }
    return parsed.toString();
  } catch {
    return trimmed;
  }
}

export function validateSipConfig(
  input: SipConfig,
  pageProtocol = typeof window === "undefined" ? "http:" : window.location.protocol
): SipConfigValidation {
  const errors: string[] = [];
  const warnings: string[] = [];
  const config: SipConfig = {
    ...input,
    username: input.username.trim(),
    domain: input.domain.trim(),
    displayName: input.displayName.trim() || "Kibal Web",
    wsServer: normalizeWsServer(input.wsServer),
    iceServers: input.iceServers.map((value) => value.trim()).filter(Boolean)
  };

  if (!config.username) {
    errors.push("내선 번호를 입력하세요.");
  } else if (!USERNAME_PATTERN.test(config.username)) {
    errors.push("내선 번호는 영문·숫자·._- 조합 32자 이내여야 합니다.");
  }

  if (!config.password) {
    errors.push("SIP 비밀번호를 입력하세요.");
  }

  if (!config.domain) {
    errors.push("서버 도메인을 입력하세요.");
  } else if (!DOMAIN_PATTERN.test(config.domain)) {
    errors.push("서버 도메인은 IP 또는 호스트명만 입력하세요. (예: 192.168.11.2)");
  }

  let wsUrl: URL | undefined;
  if (!config.wsServer) {
    errors.push("WebSocket URL을 입력하세요.");
  } else {
    try {
      wsUrl = new URL(config.wsServer);
    } catch {
      errors.push(`WebSocket URL 형식이 올바르지 않습니다: ${config.wsServer}`);
    }
  }

  if (wsUrl) {
    if (wsUrl.protocol !== "ws:" && wsUrl.protocol !== "wss:") {
      errors.push("WebSocket URL은 ws:// 또는 wss://로 시작해야 합니다.");
    } else if (pageProtocol === "https:" && wsUrl.protocol === "ws:") {
      errors.push("HTTPS 페이지에서는 wss:// WebSocket만 사용할 수 있습니다.");
    }
    if (wsUrl.pathname !== "/ws") {
      warnings.push("Asterisk WebSocket 경로는 일반적으로 /ws 입니다.");
    }
  }

  config.iceServers.forEach((server) => {
    if (!/^(stun|turn|turns):/i.test(server)) {
      warnings.push(`STUN/TURN URL 형식을 확인하세요: ${server}`);
    }
  });

  return { config, errors, warnings };
}

export function loadStoredConfig(): SipConfig {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return defaultConfig;
    }
    const stored = JSON.parse(raw) as Partial<SipConfig>;
    return {
      ...defaultConfig,
      ...stored,
      password: defaultConfig.password,
      iceServers: Array.isArray(stored.iceServers)
        ? stored.iceServers.filter((value): value is string => typeof value === "string")
        : defaultConfig.iceServers
    };
  } catch {
    return defaultConfig;
  }
}

export function saveStoredConfig(config: SipConfig): void {
  const persisted = { ...config, password: "" };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(persisted));
}
