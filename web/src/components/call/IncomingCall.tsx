/** @format */

import { Phone, User, Check, X } from 'lucide-react';
import { useEffect } from 'react';

interface IncomingCallProps {
  caller: string;
  callerAvatar?: string;
  isVideo?: boolean;
  onAccept: () => void;
  onReject: () => void;
}

export default function IncomingCall({
  caller,
  callerAvatar,
  isVideo = false,
  onAccept,
  onReject,
}: IncomingCallProps) {
  useEffect(() => {
    // 자동 거절 타이머 (30초)
    const timer = setTimeout(() => {
      onReject();
    }, 30000);

    return () => clearTimeout(timer);
  }, [onReject]);

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center">
      <div className="bg-gray-800 rounded-xl p-8 max-w-sm w-full mx-4 text-center">
        <div className="mb-6">
          {callerAvatar ? (
            <img src={callerAvatar} alt={caller} className="w-20 h-20 rounded-full mx-auto" />
          ) : (
            <div className="w-20 h-20 bg-gray-700 rounded-full flex items-center justify-center mx-auto">
              <User className="w-10 h-10 text-gray-400" />
            </div>
          )}
          <h2 className="text-xl font-bold mt-3">{caller}</h2>
          <p className="text-sm text-gray-400 mt-1">
            {isVideo ? 'Video Call' : 'Voice Call'}
          </p>
        </div>

        <div className="flex items-center justify-center space-x-6">
          <button
            onClick={onReject}
            className="w-14 h-14 bg-red-600 rounded-full flex items-center justify-center text-white hover:bg-red-700 transition-colors"
          >
            <X className="w-6 h-6" />
          </button>

          <button
            onClick={onAccept}
            className="w-14 h-14 bg-green-600 rounded-full flex items-center justify-center text-white hover:bg-green-700 transition-colors"
          >
            <Check className="w-6 h-6" />
          </button>
        </div>

        <p className="text-xs text-gray-500 mt-4">
          Will auto-reject in 30 seconds
        </p>
      </div>
    </div>
  );
}
