/** @format */

import { Phone, Delete } from 'lucide-react';

interface DialPadProps {
  onDigitPress: (digit: string) => void;
  onClear: () => void;
  onDelete: () => void;
  number: string;
  maxLength?: number;
}

const DIAL_PAD_KEYS = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['*', '0', '#'],
];

export default function DialPad({
  onDigitPress,
  onClear,
  onDelete,
  number,
  maxLength = 20,
}: DialPadProps) {
  const handleKeyPress = (key: string) => {
    if (number.length >= maxLength && key !== '' ) return;
    if (key === 'clear') {
      onClear();
    } else if (key === 'delete') {
      onDelete();
    } else {
      onDigitPress(key);
    }
  };

  return (
    <div className="grid grid-cols-3 gap-2 p-4">
      {DIAL_PAD_KEYS.flat().map((key) => {
        const isSpecial = key === '*' || key === '#';
        const displayText = isSpecial ? key : key;
        const letters =
          key === '2' ? 'ABC' :
          key === '3' ? 'DEF' :
          key === '4' ? 'GHI' :
          key === '5' ? 'JKL' :
          key === '6' ? 'MNO' :
          key === '7' ? 'PQRS' :
          key === '8' ? 'TUV' :
          key === '9' ? 'WXYZ' : '';
        return (
          <button
            key={key}
            onClick={() => handleKeyPress(key)}
            disabled={number.length >= maxLength && !isSpecial}
            className="flex flex-col items-center justify-center h-16 bg-gray-800 border border-gray-700 rounded hover:bg-gray-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span className="text-xl font-medium text-white">{displayText}</span>
            {letters && <span className="text-xs text-gray-400 mt-0.5">{letters}</span>}
          </button>
        );
      })}
      <button
        onClick={() => handleKeyPress('clear')}
        className="flex items-center justify-center h-16 bg-gray-800 border border-gray-700 rounded hover:bg-gray-700 transition-colors col-span-1"
      >
        <span className="text-sm text-gray-300">Clear</span>
      </button>
      <button
        onClick={() => handleKeyPress('delete')}
        className="flex items-center justify-center h-16 bg-gray-800 border border-gray-700 rounded hover:bg-gray-700 transition-colors col-span-1"
      >
        <Delete className="w-5 h-5 text-gray-300" />
      </button>
      <button
        onClick={() => onDigitPress('call')}
        className="flex items-center justify-center h-16 bg-green-600 border border-green-700 rounded hover:bg-green-700 transition-colors col-span-1"
      >
        <Phone className="w-6 h-6 text-white" />
      </button>
    </div>
  );
}
