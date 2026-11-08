/** @format */

import { Phone, Video, PhoneOff } from 'lucide-react';

interface ContactCardProps {
  name: string;
  number: string;
  avatar?: string;
  status?: 'available' | 'busy' | 'offline';
  onCall?: () => void;
  onVideoCall?: () => void;
  onSelect?: () => void;
}

export default function ContactCard({
  name,
  number,
  avatar,
  status = 'available',
  onCall,
  onVideoCall,
  onSelect,
}: ContactCardProps) {
  const statusColors = {
    available: 'bg-green-500',
    busy: 'bg-red-500',
    offline: 'bg-gray-500',
  };

  return (
    <div
      className="bg-gray-800 border border-gray-700 rounded-lg p-4 flex items-center space-x-3 cursor-pointer hover:bg-gray-700/50 transition-colors"
      onClick={onSelect}
    >
      <div className="relative flex-shrink-0">
        {avatar ? (
          <img src={avatar} alt={name} className="w-12 h-12 rounded-full" />
        ) : (
          <div className="w-12 h-12 bg-gray-700 rounded-full flex items-center justify-center">
            <span className="text-xl text-gray-300">{name.charAt(0)}</span>
          </div>
        )}
        <span className={`absolute bottom-0 right-0 w-3 h-3 rounded-full ${statusColors[status]}`} />
      </div>

      <div className="flex-1 min-w-0">
        <h3 className="font-medium text-white">{name}</h3>
        <p className="text-sm text-gray-400 truncate">{number}</p>
      </div>

      {onCall && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            onCall();
          }}
          className="p-2 text-green-400 hover:bg-gray-700 rounded"
          title="Audio Call"
        >
          <Phone className="w-5 h-5" />
        </button>
      )}

      {onVideoCall && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            onVideoCall();
          }}
          className="p-2 text-blue-400 hover:bg-gray-700 rounded"
          title="Video Call"
        >
          <Video className="w-5 h-5" />
        </button>
      )}
    </div>
  );
}
