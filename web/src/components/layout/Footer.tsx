/** @format */

import { Phone } from 'lucide-react';
import { useCallTimer } from '@/hooks';
import { useState, useEffect, useRef } from 'react';

export default function Footer() {
  const [showDetails, setShowDetails] = useState(false);

  return (
    <footer className="bg-gray-800 border-t border-gray-700 px-4 py-3 text-sm text-gray-400">
      <div className="flex items-center justify-between">
        <span>© 2024 Kibal SIP Client</span>
        <button
          className="hover:text-gray-200 transition-colors"
          onClick={() => setShowDetails(!showDetails)}
        >
          {showDetails ? 'Hide' : 'Show'} Connection Details
        </button>
      </div>
      {showDetails && (
        <div className="mt-2 p-3 bg-gray-900 rounded text-xs">
          <pre className="whitespace-pre-wrap">
            {JSON.stringify(
              {
                version: '1.0.0',
                webrtc: '1.0',
                userAgent: navigator.userAgent,
              },
              null,
              2
            )}
          </pre>
        </div>
      )}
    </footer>
  );
}
