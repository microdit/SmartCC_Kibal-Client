/** @format */

import { Clock, Phone, Video, PhoneIncoming, PhoneMissed, VideoMedium } from 'lucide-react';
import { useState } from 'react';
import type { CallHistoryEntry } from '@/types';

export default function HistoryPage() {
  const [activeTab, setActiveTab] = useState<'all' | 'missed' | 'dialed' | 'received'>('all');

  // Mock data
  const history: CallHistoryEntry[] = [
    {
      id: '1',
      type: 'call',
      number: '1001',
      direction: 'outgoing',
      status: 'completed',
      duration: 342,
      timestamp: Date.now() - 3600000,
    },
    {
      id: '2',
      type: 'call',
      number: '1002',
      direction: 'incoming',
      status: 'missed',
      duration: 0,
      timestamp: Date.now() - 7200000,
    },
    {
      id: '3',
      type: 'video',
      number: '1003',
      direction: 'outgoing',
      status: 'completed',
      duration: 612,
      timestamp: Date.now() - 86400000,
    },
    {
      id: '4',
      type: 'conference',
      number: 'Sales Meeting',
      direction: 'outgoing',
      status: 'completed',
      duration: 1800,
      timestamp: Date.now() - 172800000,
    },
  ];

  const formatDuration = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  };

  const formatTime = (timestamp: number): string => {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days > 1) {
      return date.toLocaleDateString();
    } else if (days === 1) {
      return 'Yesterday';
    } else {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
  };

  const getStatusIcon = (entry: CallHistoryEntry) => {
    if (entry.direction === 'outgoing') {
      return entry.type === 'video' ? <Video className="w-4 h-4 text-blue-400" /> : <Phone className="w-4 h-4 text-green-400" />;
    } else {
      if (entry.status === 'missed') {
        return <PhoneMissed className="w-4 h-4 text-red-400" />;
      }
      return entry.type === 'video' ? <Video className="w-4 h-4 text-blue-400" /> : <PhoneIncoming className="w-4 h-4 text-green-400" />;
    }
  };

  const filteredHistory = history.filter((entry) => {
    switch (activeTab) {
      case 'all':
        return true;
      case 'missed':
        return entry.status === 'missed';
      case 'dialed':
        return entry.direction === 'outgoing';
      case 'received':
        return entry.direction === 'incoming';
      default:
        return true;
    }
  });

  return (
    <div className="container mx-auto p-6">
      <h2 className="text-xl font-bold text-white mb-4">Call History</h2>

      {/* Tabs */}
      <div className="flex space-x-1 mb-4 bg-gray-800 border border-gray-700 rounded-lg p-1">
        {(['all', 'missed', 'dialed', 'received'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded text-sm font-medium transition-colors ${
              activeTab === tab
                ? 'bg-blue-600 text-white'
                : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {/* List */}
      <div className="space-y-2">
        {filteredHistory.length === 0 ? (
          <div className="text-center py-8 text-gray-500">
            No calls in this category
          </div>
        ) : (
          filteredHistory.map((entry) => (
            <div
              key={entry.id}
              className="bg-gray-800 border border-gray-700 rounded-lg p-4 flex items-center justify-between hover:bg-gray-700/50 transition-colors"
            >
              <div className="flex items-center space-x-3">
                <div className="flex-shrink-0">
                  {getStatusIcon(entry)}
                </div>
                <div>
                  <div className="font-medium text-white">{entry.number}</div>
                  <div className="text-sm text-gray-400 flex items-center space-x-2">
                    <span>
                      {entry.direction === 'outgoing' ? 'Outgoing' : 'Incoming'}
                    </span>
                    <span>•</span>
                    <span>{formatTime(entry.timestamp)}</span>
                    {entry.duration > 0 && (
                      <>
                        <span>•</span>
                        <span className="flex items-center">
                          <Clock className="w-3 h-3 mr-1" />
                          {formatDuration(entry.duration)}
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </div>

              <button
                onClick={() => {
                  // Redial
                  console.log('Redial:', entry.number);
                }}
                className="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded"
                title="Redial"
              >
                <Phone className="w-4 h-4" />
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
