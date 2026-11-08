/** @format */

import { useState, useCallback, useEffect } from 'react';
import { useAppStore } from '@/store';

export function useMedia() {
  const [localStream, setLocalStream] = useState<MediaStream | null>(null);
  const [remoteStream, setRemoteStream] = useState<MediaStream | null>(null);
  const [hasPermission, setHasPermission] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const requestLocalStream = useCallback(async (constraints?: MediaStreamConstraints) => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia(
        constraints || { video: true, audio: true }
      );
      setLocalStream(stream);
      setHasPermission(true);
      setError(null);
      return stream;
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Media access denied';
      setError(msg);
      setHasPermission(false);
      return null;
    }
  }, []);

  const stopLocalStream = useCallback(() => {
    if (localStream) {
      localStream.getTracks().forEach((track) => track.stop());
      setLocalStream(null);
    }
  }, [localStream]);

  const toggleAudio = useCallback(
    (enabled: boolean) => {
      if (localStream) {
        localStream.getAudioTracks().forEach((track) => {
          track.enabled = enabled;
        });
      }
    },
    [localStream]
  );

  const toggleVideo = useCallback(
    (enabled: boolean) => {
      if (localStream) {
        localStream.getVideoTracks().forEach((track) => {
          track.enabled = enabled;
        });
      }
    },
    [localStream]
  );

  useEffect(() => {
    return () => {
      stopLocalStream();
    };
  }, [stopLocalStream]);

  return {
    localStream,
    remoteStream,
    setRemoteStream,
    hasPermission,
    error,
    requestLocalStream,
    stopLocalStream,
    toggleAudio,
    toggleVideo,
  };
}
