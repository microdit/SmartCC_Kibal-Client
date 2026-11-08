/** @format */

import { useState, useEffect } from 'react';
import { AlertTriangle, CheckCircle, X } from 'lucide-react';

interface CameraTestProps {
  onTestComplete: (success: boolean, errorMessage?: string) => void;
}

export default function CameraTest({ onTestComplete }: CameraTestProps) {
  const [localStream, setLocalStream] = useState(null);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [micError, setMicError] = useState<string | null>(null);
  const [isInitialized, setIsInitialized] = useState(false);
  const [permissionStatus, setPermissionStatus] = useState<string | null>(null);

  const [audioTracks, setAudioTracks] = useState<string[]>([]);
  const [videoTracks, setVideoTracks] = useState<string[]>([]);

  const testCamera = async () => {
    setCameraError(null);
    setMicError(null);
    setPermissionStatus(null);
    setIsInitialized(false);
    setAudioTracks([]);
    setVideoTracks([]);

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: true,
      });

      setLocalStream(stream);
      setIsInitialized(true);
      setPermissionStatus('granted');

      const videoTrack = stream.getVideoTracks()[0];
      const audioTrack = stream.getAudioTracks()[0];

      setVideoTracks(videoTrack ? [videoTrack.label] : []);
      setAudioTracks(audioTrack ? [audioTrack.label] : []);

      if (videoTrack) {
        videoTrack.onended = () => {
          setVideoTracks([]);
          setCameraError('Video track ended');
        };
      }
      if (audioTrack) {
        audioTrack.onended = () => {
          setAudioTracks([]);
          setMicError('Audio track ended');
        };
      }

      onTestComplete(true);
    } catch (err: any) {
      console.error('Camera/Microphone access error:', err);
      setCameraError(err.message || 'Camera/microphone access failed');

      if (err.name === 'NotAllowedError') {
        setPermissionStatus('denied');
      } else if (err.name === 'NotFoundError') {
        setCameraError('No camera/microphone found on this device');
      } else if (err.message && err.message.includes('insecure context')) {
        setCameraError(
          'Media devices not available in insecure contexts. ' +
            'This application requires HTTPS or localhost for camera/microphone access.'
        );
      } else if (err.name === 'OverconstrainedError') {
        setCameraError('Requested media constraints not supported by this device');
      } else if (err.name === 'NotAllowedError') {
        setPermissionStatus('blocked');
      }

      onTestComplete(false, err.message || 'Camera access failed');
    }
  };

  useEffect(() => {
    return () => {
      if (localStream) {
        localStream.getTracks().forEach((track) => track.stop());
      }
    };
  }, [localStream]);

  return (
    <div className="space-y-4">
      <button
        onClick={testCamera}
        className="w-full px-6 py-3 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        disabled={isInitialized}
      >
        {isInitialized ? 'Camera Active' : 'Test Camera'}
        {isInitialized && <CheckCircle className="ml-2 w-4 h-4" />}
        {!isInitialized && <AlertTriangle className="ml-2 w-4 h-4" />}
      </button>

      {cameraError && (
        <div className="bg-red-600/20 border-red-400 text-red-400 p-3 rounded text-sm mb-2">
          {cameraError}
        </div>
      )}
      {micError && (
        <div className="bg-red-600/20 border-red-400 text-red-400 p-3 rounded text-sm mb-2">
          {micError}
        </div>
      )}
      {permissionStatus && (
        <div className="bg-blue-600/20 border-blue-400 text-blue-400 p-3 rounded text-sm mb-2">
          {permissionStatus === 'granted' ? 'Permission: Granted' : 'Permission: ' + permissionStatus}
        </div>
      )}

      {isInitialized && (
        <div className="grid grid-cols-2 gap-2 text-xs text-gray-300">
          <div>
            <span>Video Tracks:</span> <span>{videoTracks.length}</span>
          </div>
          <div>
            <span>Audio Tracks:</span> <span>{audioTracks.length}</span>
          </div>
        </div>
      )}
    </div>
  );
}