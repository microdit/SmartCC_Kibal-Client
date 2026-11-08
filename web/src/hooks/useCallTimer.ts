/** @format */

import { useState, useCallback, useEffect, useRef } from 'react';

/**
 * useCallTimer — 통화 시간 타이머 훅
 *
 * Returns:
 * - elapsedSeconds: 경과 시간 (초)
 * - formattedTime: MM:SS 형식 문자열
 * - start: 타이머 시작
 * - stop: 타이머 정지
 * - reset: 타이머 초기화
 */
export function useCallTimer() {
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  const clear = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const start = useCallback(() => {
    clear();
    const id = setInterval(() => {
      setElapsedSeconds((prev) => prev + 1);
    }, 1000);
    intervalRef.current = id;
  }, [clear]);

  const stop = useCallback(() => {
    clear();
  }, [clear]);

  const reset = useCallback(() => {
    clear();
    setElapsedSeconds(0);
  }, [clear]);

  useEffect(() => {
    return () => {
      clear();
    };
  }, [clear]);

  const formatTime = useCallback((seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }, []);

  return {
    elapsedSeconds,
    formattedTime: formatTime(elapsedSeconds),
    start,
    stop,
    reset,
  };
}
