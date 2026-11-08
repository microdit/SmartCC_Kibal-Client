/** @format */

import { useState, useEffect, useRef, useCallback } from 'react';
import { Phone, Pause, Mic, Video, Volume2, VolumeX, Maximize } from 'lucide-react';
import { useSip } from '@/hooks/useSip';
import { useCallTimer } from '@/hooks/useCallTimer';
import { useSipStore } from '@/store/sipStore';

interface CallViewProps {
  target: string;
  isVideo?: boolean;
  isIncoming?: boolean;
}

export default function CallView({ target, isVideo = false, isIncoming = false }: CallViewProps) {
  const { isMuted, isCameraOff, isSpeaker, toggleMute, toggleCamera, toggleSpeaker, localStream, remoteStream } = useSip();
  const { formattedTime, start, stop } = useCallTimer();
  const store = useSipStore();
  const [isFullScreen, setIsFullScreen] = useState(false);
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    start();
    return () => stop();
  }, [start, stop]);

  // 로컬 스트림 할당
  useEffect(() => {
    if (localVideoRef.current && localStream) {
      localVideoRef.current.srcObject = localStream;
    }
  }, [localStream]);

  // 리모트 스트림 할당
  useEffect(() => {
    if (remoteVideoRef.current && remoteStream) {
      remoteVideoRef.current.srcObject = remoteStream;
    }
  }, [remoteStream]);

  const handleEndCall = () => {
    store.setCallActive(false);
    store.setLocalStream(null);
    store.setRemoteStream(null);
    store.setSession(null);
  };

  const toggleFullScreenHandler = useCallback(() => {
    const container = document.getElementById('call-view-container');
    if (container) {
      if (document.fullscreenElement) {
        document.exitFullscreen();
      } else {
        container.requestFullscreen();
      }
    }
    setIsFullScreen(!isFullScreen);
  }, [isFullScreen]);

  return (
    <div className={`relative bg-black rounded-lg overflow-hidden ${isFullScreen ? 'fixed inset-0 z-50' : 'aspect-video'}`}>
      {/* Remote Stream (상대 화면) */}
      <div className="w-full h-full flex items-center justify-center">
        {isVideo ? (
          remoteStream ? (
            <video
              ref={remoteVideoRef}
              autoPlay
              playsInline
              className="w-full h-full object-contain"
            />
          ) : (
            <div className="text-gray-500">Waiting for remote video...</div>
          )
        ) : (
          <div className="flex flex-col items-center justify-center text-gray-500">
            <Phone className="w-16 h-16 mb-4" />
            <span className="text-lg">{target}</span>
          </div>
        )}
      </div>

      {/* 로컬 스트림 썸네일 */}
      {isVideo && localStream && (
        <div className="absolute top-4 right-4 w-32 h-24 bg-gray-800 rounded overflow-hidden">
          <video
            ref={localVideoRef}
            autoPlay
            playsInline
            muted
            className="w-full h-full object-cover"
          />
        </div>
      )}

      {/* 통화 정보 */}
      <div className="absolute top-4 left-4 bg-black/50 text-white px-3 py-1 rounded">
        <span className="font-medium">{target}</span>
        <div className="text-sm opacity-80">
          {isIncoming ? 'Incoming' : 'On Call'} • {formattedTime}
        </div>
      </div>

      {/* 컨트롤 패널 */}
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-gray-900 via-gray-900/80 to-transparent pt-8 pb-4">
        <div className="flex items-center justify-center space-x-4">
          <button
            onClick={toggleMute}
            className={`p-3 rounded-full ${isMuted ? 'bg-red-600' : 'bg-gray-700'} hover:opacity-80`}
          >
            {isMuted ? <Mic className="w-5 h-5" /> : <VolumeX className="w-5 h-5" />}
          </button>

          {isVideo && (
            <button
              onClick={toggleCamera}
              className={`p-3 rounded-full ${isCameraOff ? 'bg-red-600' : 'bg-gray-700'} hover:opacity-80`}
            >
              {isCameraOff ? <Video className="w-5 h-5" /> : <Video className="w-5 h-5 text-gray-300" />}
            </button>
          )}

          <button
            onClick={toggleSpeaker}
            className={`p-3 rounded-full ${isSpeaker ? 'bg-blue-600' : 'bg-gray-700'} hover:opacity-80`}
          >
            {isSpeaker ? <Volume2 className="w-5 h-5" /> : <VolumeX className="w-5 h-5" />}
          </button>

          <button
            onClick={toggleFullScreenHandler}
            className="p-3 rounded-full bg-gray-700 hover:bg-gray-600 transition-colors"
            title={isFullScreen ? 'Exit Fullscreen' : 'Fullscreen'}
          >
            <Maximize className="w-5 h-5" />
          </button>

          <button
            onClick={handleEndCall}
            className="p-4 rounded-full bg-red-600 hover:bg-red-700 text-white"
          >
            <Phone className="w-6 h-6" />
          </button>
        </div>
      </div>
    </div>
  );
}
