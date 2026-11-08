import React, { useState, useEffect } from 'react';

export const TestPermissionDialog = () => {
  const [cameraEnabled, setCameraEnabled] = useState(false);
  const [micEnabled, setMicEnabled] = useState(false);
  const [showDialog, setShowDialog] = useState(false);

  const checkPermissions = async () => {
    try {
      const cameraStatus = await navigator.permissions.query({ name: 'camera' });
      const micStatus = await navigator.permissions.query({ name: 'microphone' });
      setCameraEnabled(cameraStatus.state === 'granted');
      setMicEnabled(micStatus.state === 'granted');
    } catch (e) {
      console.error('Permission check failed', e);
    }
  };

  useEffect(() => {
    checkPermissions();
  }, []);

  const openBrowserSettings = (type) => {
    window.open(
      type === 'camera' ? 'chrome://settings/content/camera' : 'chrome://settings/content/microphone',
      '_blank'
    );
  };

  return (
    <div className="test-permission-dialog" style={{
      position: 'fixed',
      top: 0,
      left: 0,
      width: '100%',
      height: '100%',
      background: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }}>
      <div style={{
        background: 'white',
        padding: '2rem',
        borderRadius: '8px',
        maxWidth: '500px',
        textAlign: 'center'
      }}>
        <h3>카메라/마이크 권한 확인</h3>
        <p>Kibal Web Client에서 미디어 액세스를 사용하려면 브라우저 권한이 필요합니다.</p>
        
        <div style={{ margin: '1rem 0' }}>
          <p>카메라 권한: <span style={{ color: cameraEnabled ? 'green' : 'red' }>{cameraEnabled ? '허용됨' : '차단됨'}</span></p>
          <p>마이크 권한: <span style={{ color: micEnabled ? 'green' : 'red' }>{micEnabled ? '허용됨' : '차단됨'}</span></p>
        </div>
        
        <button 
          onClick={() => openBrowserSettings('camera')}
          style={{ margin: '0.5rem' }}
          background: '#fff'
          border: '1px solid #ccc'
        >
          카메라 설정 열기
        </button>
        <button 
          onClick={() => openBrowserSettings('microphone')}
          style={{ margin: '0.5rem' }}
          background: '#fff'
          border: '1px solid #ccc'
        >
          마이크 설정 열기
        </button>
        
        <button 
          onClick={() => setShowDialog(false)}
          style={{ margin: '0.5rem' }}
          background: '#f00'
          color: 'white'
          border: 'none'
        >
          닫기
        </button>
      </div>
    </div>
  );
};
EOF"