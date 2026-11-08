/** @format */

import { createContext, useContext, ReactNode } from 'react';
import { useAppStore } from '@/store';

const StoreContext = createContext<ReturnType<typeof useAppStore> | undefined>(undefined);

export function useStoreContext() {
  const ctx = useContext(StoreContext);
  if (!ctx) {
    throw new Error('useStoreContext must be used within a StoreProvider');
  }
  return ctx;
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const store = useAppStore();
  return (
    <StoreContext.Provider value={store}>{children}</StoreContext.Provider>
  );
}
