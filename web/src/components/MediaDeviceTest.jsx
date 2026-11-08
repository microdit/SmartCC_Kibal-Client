import React, { useState, useEffect, useRef } from 'react';

function MediaDeviceTest() {
  const [cameras, setCameras] = useState([]);
  const [microphones, setMicrophones] = useState([]);
  const [localStream, setLocalStream] = useState(null);
  const [permissionStatus, setPermissionStatus] = useState('unknown');
  const [error, setError] = useState(null);
  const videoRef = useRef(null);

  // 카메라 목록 가져오기
  useEffect(() => {
    navigator.mediaDevices.enumerateDevices()
      .then(devices => {
        const videoDevices = devices.filter(device => device.kind === 'videoinput');
        const audioDevices = devices.filter(device => device.kind === 'audioinput');
        setCameras(videoDevices);
        setMicrophones(audioDevices);
      })
      .catch(err => setError(err.message));
  }, []);

  // 미디어 스트림 가져오기
  useEffect(() => {
    if (cameras.length > 0 && microphones.length > 0) {
      const constraints = {
        video: { ideal: { facingMode: 'environment' } },
        audio: true
      };
      
      navigator.mediaDevices.getUserMedia(constraints)
        .then(stream => {
          setLocalStream(stream);
          if (videoRef) {
            videoRef.srcObject = stream;
          }
        })
        .catch(err => setError(err.message));
    }
  }, [cameras, microphones]);

  // 권한 상태 확인
  useEffect(() => {
    const checkPermission = async () => {
      try {
        const cameraStatus = await navigator.mediaDevices.getUserMedia({ video: true });
        cameraStatus.getVideoTracks().forEach(track => track.stop());
        setPermissionStatus('camera_granted');
      } catch (e) {
        setPermissionStatus('camera_blocked');
      }
      
      try {
        const microphoneStatus = await navigator.mediaDevices.getUserMedia({ audio: true });
        microphoneStatus.getAudioTracks().forEach(track => track.stop());
        setPermissionStatus(prev => 
          prev === 'microphone_granted' ? prev : 'microphone_blocked'
        );
      } catch (e) {
        setPermissionStatus(prev => prev === 'camera_granted' ? prev : 'microphone_blocked');
      }
    };
    checkPermission();
  }, []);

  return (
    <div className="media-test-page">
      <h2>미디어 디바이스 테스트</h2>
      
      <div className="device-status">
        <h3>권한 상태: {permissionStatus}</h3>
      </div>
      
      <div className="camera-section">
        <h3>카메라 디바이스</h3>
        {cameras.length === 0 ? (
          <p>카메라가 감지되지 않음</p>
        ) : (
          <select onChange={e => console.log('Select camera:', e.target.value)}>
            {cameras.map(device => (
              <option key={device.deviceId} value={device.deviceId}>
                {device.label || `카메라 ${device.deviceId}`}
              </option>
            ))}
          </select>
        )}
        </div>
      </div>
      
      <div className="microphone-section">
        <h3>마이크 디바이스</h3>
        {microphones.length === 0 ? (
          <p>마이크가 감지되지 않음</p>
        ) : (
          <select onChange={e => console.log('Select microphone:', e.target.value)}>
            {microphones.map(device => (
              <option key={device.deviceId} value={device.deviceId}>
                {device.label || `마이크 ${device.deviceId}`}
              </option>
            ))}
          </select>
        )}
        </div>
      </div>
      
      <div className="local-video-section">
        <h3>로컬 비디오 프리뷰</h3>
        {localStream ? (
          <video 
            ref={videoRef} 
            autoplay 
            playsInline 
            className="preview-video"
          />
        ) : (
          <div>비디오 스트림을 로드중...</div>
        )}
        </div>
        </div>
        </div>
      );
    }
};
export default MediaDeviceTest;