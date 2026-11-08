/** @format */

import type { SipConfig, DialButton, ThemeMode } from '@/types';

// ── SIP 설정 (환경 변수에서 로드) ──────────────────────────────────────────

export const SIP_CONFIG: SipConfig = {
  username: import.meta.env.VITE_SIP_USERNAME || '1001',
  domain: import.meta.env.VITE_SIP_DOMAIN || '192.168.11.2',
  password: import.meta.env.VITE_SIP_PASSWORD || '',
  wsPort: parseInt(import.meta.env.VITE_WS_PORT || '8090', 10),
  wsServers: import.meta.env.VITE_WSS_URL
    ? [import.meta.env.VITE_WSS_URL]
    : [`wss://${import.meta.env.VITE_SIP_DOMAIN || '192.168.11.2'}:8090/ws`],
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
  ],
};

// ── WebSocket ─────────────────────────────────────────────────────────────

export const WS_CONFIG = {
  reconnectInterval: 5000, // ms
  maxReconnectAttempts: 5,
  heartbeatInterval: 30000, // ms
};

// ── 테스트 계정 (개발용) ─────────────────────────────────────────────────

export const TEST_ACCOUNTS = [
  { username: '1001', displayName: 'User 1001' },
  { username: '1002', displayName: 'User 1002' },
  { username: '1003', displayName: 'User 1003' },
  { username: '1004', displayName: 'User 1004' },
];

export const CONFERENCE_ROOM_ID = '6000';

// ── 다이얼 패드 버튼 ──────────────────────────────────────────────────────

export const DIAL_PAD_BUTTONS: DialButton[] = [
  { label: '1', value: '1' },
  { label: '2', value: '2' },
  { label: '3', value: '3' },
  { label: '4', value: '4' },
  { label: '5', value: '5' },
  { label: '6', value: '6' },
  { label: '7', value: '7' },
  { label: '8', value: '8' },
  { label: '9', value: '9' },
  { label: '*', value: '*' },
  { label: '0', value: '0' },
  { label: '#', value: '#' },
];

// ── 테마 ──────────────────────────────────────────────────────────────────

export const THEME_MODE: ThemeMode = (import.meta.env.VITE_THEME as ThemeMode) || 'system';

export const THEME_CONFIG = {
  storageKey: 'kibal-theme',
  defaultMode: 'dark' as const,
};

// ── UI 상수 ───────────────────────────────────────────────────────────────

export const UI_CONFIG = {
  videoPreviewSize: 160, // px (PiP 작은 창 크기)
  gridMaxParticipants: 4,
  recentCallsLimit: 50,
  dtmfTimeout: 300, // ms (버튼 길게 누르기)
};

// ── 미디어 제약 ──────────────────────────────────────────────────────────

export const VIDEO_CONSTRAINTS: MediaTrackConstraints = {
  width: { ideal: 1280 },
  height: { ideal: 720 },
  facingMode: 'user',
};

export const AUDIO_CONSTRAINTS: MediaStreamConstraints = {
  audio: {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  },
};

// ── 코덱 우선순위 ─────────────────────────────────────────────────────────

export const CODEC_PREFERENCE = {
  video: ['H264', 'VP8'],
  audio: ['OPUS', 'PCMU', 'PCMA'],
};