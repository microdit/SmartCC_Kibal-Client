/** @format */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Input } from '@/components/common/Input';
import { Button } from '@/components/common/Button';
import { Sip } from 'lucide-react';

export default function LoginPage() {
  const navigate = useNavigate();
  const [sipUri, setSipUri] = useState('');
  const [sipPassword, setSipPassword] = useState('');
  const [sipServer, setSipServer] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!sipUri || !sipPassword || !sipServer) return;

    setIsLoading(true);

    // Save config to localStorage for persistence
    localStorage.setItem(
      'sip-config',
      JSON.stringify({ uri: sipUri, password: sipPassword, server: sipServer, displayName })
    );

    // Simulate registration
    setTimeout(() => {
      setIsLoading(false);
      navigate('/dialer');
    }, 500);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-900">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="flex items-center justify-center space-x-2 mb-4">
            <Sip className="w-8 h-8 text-blue-500" />
            <h1 className="text-2xl font-bold text-white">Kibal SIP Client</h1>
          </div>
          <p className="text-gray-400">Enter your SIP account details to connect</p>
        </div>

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm text-gray-300 mb-1">Display Name</label>
            <Input
              type="text"
              placeholder="John Doe"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              autoComplete="name"
            />
          </div>

          <div>
            <label className="block text-sm text-gray-300 mb-1">SIP Username</label>
            <Input
              type="text"
              placeholder="username"
              value={sipUri}
              onChange={(e) => setSipUri(e.target.value)}
              autoComplete="username"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-gray-300 mb-1">Password</label>
            <Input
              type="password"
              placeholder="••••••••"
              value={sipPassword}
              onChange={(e) => setSipPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-gray-300 mb-1">SIP Server</label>
            <Input
              type="text"
              placeholder="sip.example.com"
              value={sipServer}
              onChange={(e) => setSipServer(e.target.value)}
              required
            />
          </div>

          <Button
            type="submit"
            variant="primary"
            size="lg"
            className="w-full"
            disabled={isLoading}
          >
            {isLoading ? 'Connecting...' : 'Connect'}
          </Button>
        </form>

        <p className="text-xs text-gray-500 text-center mt-6">
          Make sure your firewall allows SIP traffic (UDP/TCP 5060)
        </p>
      </div>
    </div>
  );
}
