/** @format */

import { create } from 'zustand';
import { devtools, persist, subscribeWithSelector } from 'zustand/middleware';
import type {
  SipConfig,
  CallHistoryEntry,
  ConfParticipant,
  CallUiState,
  CallScreenMode,
} from '@/types';
import type { SipState } from './sipStore';

// ── 메인 앱 상태 인터페이스 ───────────────────────────────────────────────

export interface AppState {
  // 회면 상태
  isConferenceOpen: boolean;
  conferenceParticipants: ConfParticipant[];
  isInConference: boolean;

  // 통화 기록
  callHistory: CallHistoryEntry[];

  // UI 상태
  dialerNumber: string;
  isDialerOpen: boolean;
  theme: 'light' | 'dark';
}

export interface AppActions {
  setConferenceOpen: (open: boolean) => void;
  setInConference: (inConf: boolean) => void;
  setConferenceParticipants: (participants: ConfParticipant[]) => void;
  addCallHistoryEntry: (entry: CallHistoryEntry) => void;
  clearCallHistory: () => void;
  setDialerNumber: (num: string) => void;
  setDialerOpen: (open: boolean) => void;
  toggleDialer: () => void;
  setTheme: (theme: 'light' | 'dark') => void;
  reset: () => void;
}

// ── 통합 스토어 (Zustand + DevTools + Persist) ───────────────────────────

export interface RootState extends SipState, AppState {
  sip: SipState;
  app: AppState;
  appActions: AppActions;
}

// 액션만 분리한 스토어
export const useAppStore = create<AppState & AppActions>()(
  subscribeWithSelector(
    devtools(
      persist(
        (set, get) => ({
          isConferenceOpen: false,
          conferenceParticipants: [],
          isInConference: false,
          callHistory: [],
          dialerNumber: '',
          isDialerOpen: false,
          theme: 'dark',

          setConferenceOpen: (open) => set({ isConferenceOpen: open }),
          setInConference: (inConf) => set({ isInConference: inConf }),
          setConferenceParticipants: (participants) => set({ conferenceParticipants: participants }),
          addCallHistoryEntry: (entry) =>
            set((prev) => ({
              callHistory: [entry, ...prev.callHistory].slice(0, 100),
            })),
          clearCallHistory: () => set({ callHistory: [] }),
          setDialerNumber: (num) => set({ dialerNumber: num }),
          setDialerOpen: (open) => set({ isDialerOpen: open }),
          toggleDialer: () => set((prev) => ({ isDialerOpen: !prev.isDialerOpen })),
          setTheme: (theme) => set({ theme }),
          reset: () =>
            set({
              isConferenceOpen: false,
              conferenceParticipants: [],
              isInConference: false,
              callHistory: [],
              dialerNumber: '',
              isDialerOpen: false,
            }),
        }),
        { name: 'kibal-app-storage', version: 1 }
      )
    )
  )
);
