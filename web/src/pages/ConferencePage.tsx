/** @format */

import { useState, useEffect, useRef } from 'react';
import { Users, Mic, MicOff, Video, VideoOff, Hand, Send, LeaveRoom } from 'lucide-react';
import { useConference } from '@/hooks/useConference';
import VideoPlayer from '@/components/common/VideoPlayer';
import { Input } from '@/components/common/Input';
import { Badge } from '@/components/common/Badge';
import { Button } from '@/components/common/Button';

export default function ConferencePage() {
  const {
    isInConference,
    conferenceParticipants,
    elapsedSeconds,
    formattedTime,
    joinConference,
    leaveConference,
    toggleMuteParticipant,
    raiseHand,
  } = useConference();

  const [roomId, setRoomId] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [showJoinForm, setShowJoinForm] = useState(!isInConference);
  const localVideoRef = useRef<HTMLVideoElement>(null);

  // Simulate getting local stream
  useEffect(() => {
    if (isInConference && localVideoRef.current) {
      navigator.mediaDevices.getUserMedia({ video: true, audio: true })
        .then((stream) => {
          if (localVideoRef.current) {
            localVideoRef.current.srcObject = stream;
          }
        })
        .catch(console.error);
    }
  }, [isInConference]);

  const handleJoin = async () => {
    if (!roomId || !displayName) return;
    await joinConference(roomId, displayName);
    setShowJoinForm(false);
  };

  if (showJoinForm || !isInConference) {
    return (
      <div className="container mx-auto p-6 max-w-md">
        <div className="bg-gray-800 border border-gray-700 rounded-xl p-6">
          <h2 className="text-xl font-bold text-white mb-4 flex items-center">
            <Users className="w-5 h-5 mr-2" />
            Join Conference
          </h2>

          <Input
            type="text"
            placeholder="Room ID"
            value={roomId}
            onChange={(e) => setRoomId(e.target.value)}
            className="mb-3"
          />
          <Input
            type="text"
            placeholder="Display Name"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            className="mb-4"
          />

          <Button
            variant="primary"
            className="w-full"
            onClick={handleJoin}
            disabled={!roomId || !displayName}
          >
            Join Conference
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-4">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-white">Conference Room</h2>
          <p className="text-sm text-gray-400">Room ID: {roomId} • Duration: {formattedTime}</p>
        </div>
        <Button variant="danger" onClick={leaveConference}>
          <LeaveRoom className="w-4 h-4 mr-2" />
          Leave
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {/* Local video */}
        <div className="relative bg-black rounded-lg overflow-hidden aspect-video">
          <video
            ref={localVideoRef}
            autoPlay
            playsInline
            muted
            className="w-full h-full object-cover"
          />
          {conferenceParticipants.find(p => p.id === 'local')?.isMuted && (
            <div className="absolute top-2 right-2">
              <Badge variant="danger"><MicOff className="w-3 h-3" /></Badge>
            </div>
          )}
          <div className="absolute bottom-2 left-2 bg-black/50 text-white px-2 py-1 rounded text-sm">
            {conferenceParticipants.find(p => p.id === 'local')?.displayName || 'You'}
          </div>
        </div>

        {/* Participant videos */}
        {conferenceParticipants.filter(p => p.id !== 'local').map((participant) => (
          <div key={participant.id} className="relative bg-black rounded-lg overflow-hidden aspect-video">
            <VideoPlayer stream={null} objectFit="cover" />
            <div className="absolute top-2 right-2 space-y-1">
              {participant.isMuted && (
                <Badge variant="danger"><MicOff className="w-3 h-3" /></Badge>
              )}
              {participant.isHandRaised && (
                <Badge variant="warning"><Hand className="w-3 h-3" /></Badge>
              )}
            </div>
            <div className="absolute bottom-2 left-2 bg-black/50 text-white px-2 py-1 rounded text-sm">
              {participant.displayName}
            </div>
          </div>
        ))}
      </div>

      {/* Controls */}
      <div className="fixed bottom-6 left-0 right-0 flex justify-center">
        <div className="flex items-center space-x-4 bg-gray-800 border border-gray-700 rounded-full px-4 py-3">
          <button className="p-3 rounded-full bg-gray-700 hover:bg-gray-600">
            <Mic className="w-5 h-5 text-white" />
          </button>
          <button className="p-3 rounded-full bg-gray-700 hover:bg-gray-600">
            <Video className="w-5 h-5 text-white" />
          </button>
          <button
            onClick={() => raiseHand('local')}
            className="p-3 rounded-full bg-gray-700 hover:bg-gray-600"
          >
            <Hand className="w-5 h-5 text-white" />
          </button>
          <button className="p-3 rounded-full bg-gray-700 hover:bg-gray-600">
            <Send className="w-5 h-5 text-white" />
          </button>
          <button className="p-3 rounded-full bg-red-600 hover:bg-red-700">
            <LeaveRoom className="w-5 h-5 text-white" />
          </button>
        </div>
      </div>
    </div>
  );
}
