/** @format */

import { useSearchParams, useNavigate } from 'react-router-dom';
import CallView from '@/components/call/CallView';

export default function CallPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const target = searchParams.get('target') || 'Unknown';
  const isVideo = searchParams.get('video') === 'true';

  return (
    <div className="container mx-auto p-4">
      <CallView target={target} isVideo={isVideo} />
    </div>
  );
}
