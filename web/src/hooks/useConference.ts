/** @format */

import { useCallback, useEffect } from 'react';
import { useAppStore } from '@/store';
import { useCallTimer } from './useCallTimer';
import type { CallHistoryEntry, ConfParticipant } from '@/types';

export function useConference() {
  const {
    isInConference,
    conferenceParticipants,
    setInConference,
    setConferenceParticipants,
    isDialerOpen,
    toggleDialer,
    addCallHistoryEntry,
    dialerNumber,
  } = useAppStore();
  const { elapsedSeconds, formattedTime, start: startTimer, stop: stopTimer } = useCallTimer();

  const joinConference = useCallback(
    async (roomId: string, displayName: string) => {
      setInConference(true);
      startTimer();
      const participant: ConfParticipant = {
        id: 'local',
        displayName,
        isMuted: false,
        isHandRaised: false,
        joinedAt: Date.now(),
      };
      setConferenceParticipants([participant]);
      return true;
    },
    [setInConference, startTimer, setConferenceParticipants]
  );

  const leaveConference = useCallback(async () => {
    const entry: CallHistoryEntry = {
      id: `conf-${Date.now()}`,
      type: 'conference',
      number: dialerNumber || 'Conference',
      direction: 'outgoing',
      status: 'completed',
      duration: elapsedSeconds,
      timestamp: Date.now(),
    };
    addCallHistoryEntry(entry);
    setInConference(false);
    stopTimer();
  }, [
    setInConference,
    stopTimer,
    addCallHistoryEntry,
    dialerNumber,
    elapsedSeconds,
  ]);

  const toggleMuteParticipant = useCallback(
    (id: string) => {
      setConferenceParticipants(
        conferenceParticipants.map((p) =>
          p.id === id ? { ...p, isMuted: !p.isMuted } : p
        )
      );
    },
    [conferenceParticipants, setConferenceParticipants]
  );

  const raiseHand = useCallback(
    (id: string) => {
      setConferenceParticipants(
        conferenceParticipants.map((p) =>
          p.id === id ? { ...p, isHandRaised: !p.isHandRaised } : p
        )
      );
    },
    [conferenceParticipants, setConferenceParticipants]
  );

  useEffect(() => {
    return () => {
      if (isInConference) {
        stopTimer();
      }
    };
  }, [isInConference, stopTimer]);

  return {
    isInConference,
    conferenceParticipants,
    elapsedSeconds,
    formattedTime,
    joinConference,
    leaveConference,
    toggleMuteParticipant,
    raiseHand,
    isDialerOpen,
    toggleDialer,
  };
}
