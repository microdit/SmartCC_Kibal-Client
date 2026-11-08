/** @format */

import { createContext, useContext, ReactNode } from 'react';
import { useSip } from '@/hooks/useSip';

interface SipContextValue {
  register: ReturnType<typeof useSip>['register'];
  unregister: ReturnType<typeof useSip>['unregister'];
  makeCall: ReturnType<typeof useSip>['makeCall'];
  answerCall: ReturnType<typeof useSip>['answerCall'];
  hangup: ReturnType<typeof useSip>['hangup'];
}

const SipContext = createContext<SipContextValue | undefined>(undefined);

export function useSipContext() {
  const ctx = useContext(SipContext);
  if (!ctx) {
    throw new Error('useSipContext must be used within a SipProvider');
  }
  return ctx;
}

export function SipProvider({ children }: { children: ReactNode }) {
  const sip = useSip();

  return (
    <SipContext.Provider
      value={{
        register: sip.register,
        unregister: sip.unregister,
        makeCall: sip.makeCall,
        answerCall: sip.answerCall,
        hangup: sip.hangup,
      }}
    >
      {children}
    </SipContext.Provider>
  );
}
