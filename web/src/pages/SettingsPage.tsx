/** @format */

import { useState } from 'react';
import { Input } from '@/components/common/Input';
import { Button } from '@/components/common/Button';
import CameraTest from '@/components/features/CameraTest';

export default function SettingsPage() {
  const [sipUri, setSipUri] = useState('');
  const [sipPassword, setSipPassword] = useState('');
  const [showCameraTest, setShowCameraTest] = useState(false);
  const [cameraTestResult, setCameraTestResult] = useState(null);

  const handleCameraTest = () => {
    setShowCameraTest(true);
    setCameraTestResult(null);
  };

  const handleCameraTestComplete = (success, errorMessage) => {
    setCameraTestResult(success ? { success, errorMessage } : null);
    setShowCameraTest(false);
  };

  return (
    <div className="container mx-auto p-6 max-w-2xl">
      <h2>Settings</h2>
      <CameraTest onTestComplete={handleCameraTestComplete} visible={showCameraTest} />
      <div className="bg-gray-800 border border-gray-700 rounded-xl p-6">
        <div className="space-y-4">
          <div>
            <label>SIP Username</label>
            <Input type="text" placeholder="username" value={sipUri}
              onChange={(e) => setSipUri(e.target.value)} />
          </div>
          <div>
            <label>Password</label>
            <Input type="password" placeholder="•••••••" value={sipPassword}
              onChange={(e) => setSipPassword(e.target.value)} />
          </div>
        </div>
      </div>
      <div className="flex items-center justify-between pt-4 border-t border-gray-700">
        <Button variant="primary" onClick={() => alert('Saved')}>Save</Button>
      </div>
      {showCameraTest && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-gray-800 rounded-xl p-8 w-80 max-w-full">
            <h3>Camera Test</h3>
            <p>Testing camera access...</p>
            <CameraTest onTestComplete={handleCameraTestComplete} />
            {cameraTestResult && (
              <div className={cameraTestResult.success ? 'bg-green-500 text-white' : 'bg-red-500 text-white'}>
                {cameraTestResult.success ? 'Success' : 'Error'}: {cameraTestResult.errorMessage || 'Unknown'}
              </div>
            )}
            <button onClick={() => setShowCameraTest(false)} className="mt-4 btn bg-gray-600 text-white">Close</button>
          </div>
        </div>
      )}
    </div>
  );
}