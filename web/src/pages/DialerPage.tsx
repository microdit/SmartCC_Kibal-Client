/** @format */

import { useState, useEffect } from 'react';
import { Phone, Video, Delete } from 'lucide-react';
import { useSipStore } from '@/store/sipStore';
import { useAppStore } from '@/store';
import DialPad from '@/components/common/DialPad';
import IncomingCall from '@/components/call/IncomingCall';
import CallView from '@/components/call/CallView';
import { Badge } from '@/components/common/Badge';

export default function DialerPage() {
  const sipStore = useSipStore();
  const appStore = useAppStore();
  const [isVideo, setIsVideo] = useState(false);
  const [showIncoming, setShowIncoming] = useState(false);
  const [callerInfo, setCallerInfo] = useState<{ name: string; number: string } | null>(null);

  const {
    registration,
    isCallActive,
    session: activeSession,
    setCallActive,
    setSession,
    setLocalStream,
    setRemoteStream,
  } = sipStore;

  const { dialerNumber, setDialerNumber } = appStore;

  // Simulate incoming call
  useEffect(() => {
    const timer = setTimeout(() => {
      if (!isCallActive && registration.state === 'registered') {
        setCallerInfo({ name: 'Alice Johnson', number: '1001' });
        setShowIncoming(true);
      }
    }, 30000);

    return () => clearTimeout(timer);
  }, [isCallActive, registration.state]);

  const handleDigitPress = (digit: string) => {
    if (digit === 'call') {
      handleCall();
    } else if (digit === 'clear') {
      setDialerNumber('');
    } else if (digit === 'delete') {
      setDialerNumber(dialerNumber.slice(0, -1));
    } else if (dialerNumber.length < 20 && (digit === '*' || digit === '#' || (digit >= '0' && digit <= '9'))) {
      setDialerNumber(dialerNumber + digit);
    }
  };

  const handleCall = () => {
    setCallActive(true, isVideo);
    setSession({
      id: 'session-1',
      caller: dialerNumber,
      callee: 'local',
      state: 'active',
      direction: 'outgoing',
      startTime: new Date(),
      isVideo,
    });
  };

  const handleAcceptCall = () => {
    setShowIncoming(false);
    setCallActive(true, isVideo);
    setSession({
      id: 'session-incoming',
      caller: callerInfo?.number || 'unknown',
      callee: 'local',
      state: 'active',
      direction: 'incoming',
      startTime: new Date(),
      isVideo,
      remoteIdentity: {
        name: callerInfo?.name || 'Unknown',
        uri: callerInfo?.number || '',
      },
      isOriginating: false,
    });
  };

  const handleRejectCall = () => {
    setShowIncoming(false);
    setCallerInfo(null);
  };

  if (isCallActive && activeSession) {
    return (
      <CallView
        target={activeSession.caller || activeSession.remoteIdentity?.name || 'Unknown'}
        isVideo={activeSession.isVideo || false}
        isIncoming={activeSession.direction === 'incoming'}
      />
    );
  }

  return (
    <div className="max-w-2xl mx-auto p-6">
      {/* Registration Status */}
      <div className="flex items-center space-x-2 mb-6">
        <Badge variant={registration.state === 'registered' ? 'success' : 'danger'}>
          {registration.state === 'registered' ? 'Registered' : 'Not Registered'}
        </Badge>
        <span className="text-sm text-gray-400">{registration.error}</span>
      </div>

      {/* Incoming Call Modal */}
      {showIncoming && callerInfo && (
        <IncomingCall
          caller={callerInfo.name}
          number={callerInfo.number}
          isVideo={isVideo}
          onAccept={handleAcceptCall}
          onReject={handleRejectCall}
        />
      )}

      {/* Number Display */}
      <div className="bg-gray-800 border border-gray-700 rounded-lg p-6 mb-6">
        <div className="text-right">
          <div className="text-4xl font-light text-white font-mono tracking-wider">
            {dialerNumber || '0'}
          </div>
          {dialerNumber && (
            <Badge variant="info" size="sm" className="mt-2">
              {dialerNumber.length} digits
            </Badge>
          )}
        </div>
      </div>

      {/* Dial Pad */}
      <DialPad
        number={dialerNumber}
        onDigitPress={handleDigitPress}
        onClear={() => setDialerNumber('')}
        onDelete={() => setDialerNumber(dialerNumber.slice(0, -1))}
      />

      {/* Call Type Toggle */}
      <div className="mt-4 flex justify-center space-x-4">
        <button
          onClick={() => setIsVideo(false)}
          className={`flex items-center space-x-2 px-4 py-2 rounded ${
            !isVideo ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-300'
          }`}
        >
          <Phone className="w-4 h-4" />
          <span>Audio</span>
        </button>
        <button
          onClick={() => setIsVideo(true)}
          className={`flex items-center space-x-2 px-4 py-2 rounded ${
            isVideo ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-300'
          }`}
        >
          <Video className="w-4 h-4" />
          <span>Video</span>
        </button>
      </div>
    </div>
  );
}

