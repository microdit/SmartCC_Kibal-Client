/** @format */

/**
 * SmartCC Kibal Web Client — TypeScript 타입 정의
 * @version 1.1.0
 * @since 2026-10-29
 */

// ── SIP 설정 ──────────────────────────────────────────────────────────────

export interface SipConfig {
  username: string;
  domain: string;
  password: string;
  wsServers?: string[];
  wsPort?: number;
  displayName?: string;
  iceServers?: RTCIceServer[];
}

// ── SIP 상태 ──────────────────────────────────────────────────────────────

export type SipRegistrationState = 'unregistered' | 'registering' | 'registered' | 'failed';

export interface SipRegistrationStatus {
  state: SipRegistrationState;
  expires?: number;
  error?: string;
}

// ── 세션 ──────────────────────────────────────────────────────────────────

export type SipSessionState = 'new' | 'ringing' | 'active' | 'terminated' | 'failed';

export type SipSessionDirection = 'incoming' | 'outgoing';

export interface SipSessionInfo {
  id: string;
  state: SipSessionState;
  remoteIdentity: {
    name: string;
    uri: string;
  };
  isOriginating: boolean;
  startTime?: Date;
  endTime?: Date;
  // UI용 확장 필드
  caller?: string;
  callee?: string;
  direction?: SipSessionDirection;
  isVideo?: boolean;
  duration?: number;
}

export interface CallOptions {
  video?: boolean;
  audio?: boolean;
}

// ── 회의 ──────────────────────────────────────────────────────────────────

export interface ConfParticipant {
  id: string;
  name: string;
  displayName?: string;
  stream?: MediaStream;
  isActive: boolean;
  isMuted?: boolean;
  isHandRaised?: boolean;
  joinedAt?: number;
}

export type ConferenceMode = 'voice' | 'video' | 'broadcast';

export interface ConferenceConfig {
  roomId: string;
  mode: ConferenceMode;
  maxParticipants: number;
}

// ── UI 상태 ──────────────────────────────────────────────────────────────

export type CallScreenMode = 'voice' | 'video';

export interface CallUiState {
  mode: CallScreenMode;
  isMuted: boolean;
  isCameraOff: boolean;
  isSpeaker: boolean;
  elapsedSeconds: number;
}

// ── 통화 기록 ──────────────────────────────────────────────────────────────

export type CallType = 'call' | 'video' | 'conference';
export type CallDirection = 'outgoing' | 'incoming';
export type CallStatus = 'completed' | 'missed' | 'rejected' | 'failed';

export interface CallHistoryEntry {
  id: string;
  number: string;
  name?: string;
  type: CallType;
  direction: CallDirection;
  status: CallStatus;
  startTime: Date;
  duration?: number; // seconds
  timestamp?: number;
}

// ── 테마 ──────────────────────────────────────────────────────────────────

export type ThemeMode = 'light' | 'dark' | 'system';

// ── 에러 ──────────────────────────────────────────────────────────────────

export interface KibalError {
  code: string;
  message: string;
  details?: unknown;
}

export type ApiError = KibalError & {
  status: number;
};

// ── 번호판 ──────────────────────────────────────────────────────────────────

export interface DialButton {
  label: string;
  value: string;
  type?: 'digit' | 'action';
}