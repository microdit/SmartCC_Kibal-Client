/** @format */

import { create } from 'zustand';
import { devtools, subscribeWithSelector } from 'zustand/middleware';
import type {
  SipRegistrationState,
  SipSessionInfo,
  CallHistoryEntry,
  ConfParticipant,
  CallUiState,
  CallScreenMode,
} from '@/types';

// ── 상태 인터페이스 ──────────────────────────────────────────────────────

export interface SipState {
  registration: {
    state: SipRegistrationState;
    expires?: number;
    error?: string;
  };
  session: SipSessionInfo | null;
  isCallActive: boolean;
  isVideoCall: boolean;
  isMuted: boolean;
  isCameraOff: boolean;
  isSpeaker: boolean;
  elapsedSeconds: number;
  callStartTime: number | null;
  localStream: MediaStream | null;
  remoteStream: MediaStream | null;
  error?: string;
}

export interface SipActions {
  setRegistration: (state: SipRegistrationState, expires?: number, error?: string) => void;
  setSession: (session: SipSessionInfo | null) => void;
  setCallActive: (active: boolean, isVideo?: boolean) => void;
  setMuted: (muted: boolean) => void;
  setCameraOff: (off: boolean) => void;
  setSpeaker: (speaker: boolean) => void;
  setLocalStream: (stream: MediaStream | null) => void;
  setRemoteStream: (stream: MediaStream | null) => void;
  setError: (error?: string) => void;
  reset: () => void;
}

// 스토어 생성
export const useSipStore = create<SipState & SipActions>()(
  devtools(
    (set, get) => ({
      registration: { state: 'unregistered' },
      session: null,
      isCallActive: false,
      isVideoCall: false,
      isMuted: false,
      isCameraOff: false,
      isSpeaker: false,
      elapsedSeconds: 0,
      callStartTime: null,
      localStream: null,
      remoteStream: null,
      error: undefined,

      setRegistration: (state, expires?, error?) =>
        set((prev) => ({
          registration: { state, expires, error },
          error: error ? error : prev.error,
        })),

      setSession: (session) => set({ session }),

      setCallActive: (active, isVideo = false) =>
        set((prev) => ({
          isCallActive: active,
          isVideoCall: active ? (isVideo ?? prev.isVideoCall) : false,
          callStartTime: active ? Date.now() : null,
          elapsedSeconds: active ? 0 : 0,
        })),

      setMuted: (muted) => set({ isMuted: muted }),
      setCameraOff: (off) => set({ isCameraOff: off }),
      setSpeaker: (speaker) => set({ isSpeaker: speaker }),
      setLocalStream: (stream) => set({ localStream: stream }),
      setRemoteStream: (stream) => set({ remoteStream: stream }),
      setError: (error) => set({ error }),

      reset: () =>
        set({
          registration: { state: 'unregistered' },
          session: null,
          isCallActive: false,
          isVideoCall: false,
          isMuted: false,
          isCameraOff: false,
          isSpeaker: false,
          elapsedSeconds: 0,
          callStartTime: null,
          localStream: null,
          remoteStream: null,
          error: undefined,
        }),
    }),
    { name: 'kibal-sip-store' }
  )
);