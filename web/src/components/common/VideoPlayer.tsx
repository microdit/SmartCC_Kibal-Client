/** @format */

import { cn } from '@/utils/cn';

interface VideoPlayerProps {
  stream: MediaStream | null;
  muted?: boolean;
  autoPlay?: boolean;
  playsInline?: boolean;
  className?: string;
  objectFit?: 'contain' | 'cover';
}

export default function VideoPlayer({
  stream,
  muted = false,
  autoPlay = true,
  playsInline = true,
  className,
  objectFit = 'cover',
}: VideoPlayerProps) {
  return (
    <video
      className={cn(
        'w-full h-full bg-black',
        `object-${objectFit}`,
        'rounded-lg',
        className
      )}
      autoPlay={autoPlay}
      playsInline={playsInline}
      muted={muted}
      ref={(el) => {
        if (el && stream) {
          el.srcObject = stream;
        }
      }}
    />
  );
}
