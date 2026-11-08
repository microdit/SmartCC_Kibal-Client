/** @format */

import { useEffect, useCallback, useState } from 'react';
import { useSipStore } from '@/store/sipStore';
import type { SipRegistrationState } from '@/types';

interface SipClient {
  register: () => Promise<void>;
  unregister: () => Promise<void>;
  setConfig: (config: any) => void;
  on: (event: string, cb: (...args: any[]) => void) => void;
  off: (event: string, cb: (...args: any[]) => void) => void;
  destroy: () => void;
}

let client: SipClient | null = null;

async function createSipClient(config: any): Promise<SipClient> {
  // 동적 импорт для 코드 스플리팅
  const { SipClient } = await import('@/sip/SipClient');
  const c = new SipClient(config);
  await c.init();
  return c as unknown as SipClient;
}

export function useSip() {
  const {
    registration,
    session,
    isCallActive,
    isMuted,
    isCameraOff,
    isSpeaker,
    localStream,
    remoteStream,
    setRegistration,
    setSession,
    setCallActive,
    setMuted,
    setCameraOff,
    setSpeaker,
    setLocalStream,
    setRemoteStream,
    reset,
  } = useSipStore();

  const [isReady, setIsReady] = useState(false);

  const register = useCallback(async (config: any) => {
    try {
      setRegistration('registering');
      client = await createSipClient(config);

      client.on('registered', () => {
        setRegistration('registered', undefined);
      });
      client.on('failed', (err: string) => {
        setRegistration('failed', undefined, err);
      });
      client.on('unregistered', () => {
        setRegistration('unregistered');
      });

      await client.register();
      setIsReady(true);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setRegistration('failed', undefined, msg);
    }
  }, [setRegistration]);

  const unregister = useCallback(async () => {
    if (client) {
      await client.unregister();
      client.destroy();
      client = null;
      setIsReady(false);
      setRegistration('unregistered');
    }
  }, [setRegistration]);

  const makeCall = useCallback(async (target: string, video = false) => {
    if (!client) return;
    setCallActive(true, video);
  }, [setCallActive]);

  const answerCall = useCallback(async () => {
    if (!client) return;
    setCallActive(true);
  }, [setCallActive]);

  const hangup = useCallback(async () => {
    if (client) {
      client.destroy();
      client = null;
    }
    setCallActive(false);
    setSession(null);
    setLocalStream(null);
    setRemoteStream(null);
  }, [setCallActive, setSession, setLocalStream, setRemoteStream]);

  const toggleMute = useCallback(() => {
    setMuted(!isMuted);
  }, [isMuted, setMuted]);

  const toggleCamera = useCallback(() => {
    setCameraOff(!isCameraOff);
  }, [isCameraOff, setCameraOff]);

  const toggleSpeaker = useCallback(() => {
    setSpeaker(!isSpeaker);
  }, [isSpeaker, setSpeaker]);

  return {
    registration,
    session,
    isReady,
    isCallActive,
    isMuted,
    isCameraOff,
    isSpeaker,
    localStream,
    remoteStream,
    register,
    unregister,
    makeCall,
    answerCall,
    hangup,
    toggleMute,
    toggleCamera,
    toggleSpeaker,
    reset,
  };
}
