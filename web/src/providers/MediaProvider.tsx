/** @format */

import { createContext, useContext, ReactNode } from 'react';
import { useMedia } from '@/hooks/useMedia';

const MediaContext = createContext<ReturnType<typeof useMedia> | undefined>(undefined);

export function useMediaContext() {
  const ctx = useContext(MediaContext);
  if (!ctx) {
    throw new Error('useMediaContext must be used within a MediaProvider');
  }
  return ctx;
}

export function MediaProvider({ children }: { children: ReactNode }) {
  const media = useMedia();
  return <MediaContext.Provider value={media}>{children}</MediaContext.Provider>;
}
