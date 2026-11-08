/** @format */

import type { SipConfig } from '@/types';

/**
 * MediaManager — WebRTC 미디어 스트림 관리
 *
 * 책임:
 * - getUserMedia (마이크/카메라)
 * - RTCPeerConnection 생성 및 관리
 * - ICE 후보 처리
 * - 로컬/원격 스트림 할당
 * - 리소스 정리
 *
 * @author  Kibal Team
 * @version 1.0.0
 * @since   2026-10-29
 */
export class MediaManager {
  private config: SipConfig;
  private localStream: MediaStream | null = null;
  private peerConnections: Map<string, RTCPeerConnection> = new Map();
  private readonly iceServers: RTCIceServer[];

  constructor(config: SipConfig) {
    this.config = config;
    this.iceServers = config.iceServers || [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
    ];
  }

  /**
   * 로컬 미디어 스트림 획득 (마이크 + 카메라)
   */
  async getLocalMedia(constraints: MediaStreamConstraints = { video: true, audio: true }): Promise<MediaStream> {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
      return this.localStream;
    } catch (err) {
      console.error('[MediaManager] getUserMedia failed:', err);
      throw err;
    }
  }

  /**
   * 로컬 스트림만 오디오 (음성 통화용)
   */
  async getAudioOnly(): Promise<MediaStream> {
    return this.getLocalMedia({ video: false, audio: true });
  }

  /**
   * RTCPeerConnection 생성
   */
  createPeerConnection(sessionId: string): RTCPeerConnection {
    const pc = new RTCPeerConnection({
      iceServers: this.iceServers,
    });

    // 로컬 스트림이 있으면 트랙 추가
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        pc.addTrack(track, this.localStream!);
      });
    }

    this.peerConnections.set(sessionId, pc);
    return pc;
  }

  /**
   * ICE 후보 이벤트 핸들러 설정
   * SIP.js SessionDescriptionHandler에 전달하기 위해 사용
   */
  setIceCandidateHandler(sessionId: string, onCandidate: (candidate: RTCIceCandidate) => void): void {
    const pc = this.peerConnections.get(sessionId);
    if (pc) {
      pc.onicecandidate = (event) => {
        if (event.candidate) {
          onCandidate(event.candidate);
        }
      };
    }
  }

  /**
   * RTCPeerConnection 조회
   */
  getPeerConnection(sessionId: string): RTCPeerConnection | undefined {
    return this.peerConnections.get(sessionId);
  }

  /**
   * 세션별 RTCPeerConnection 정리
   */
  closePeerConnection(sessionId: string): void {
    const pc = this.peerConnections.get(sessionId);
    if (pc) {
      pc.close();
      this.peerConnections.delete(sessionId);
    }
  }

  /**
   * 모든 리소스 정리
   */
  closeAll(): void {
    this.peerConnections.forEach((pc) => pc.close());
    this.peerConnections.clear();

    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop());
      this.localStream = null;
    }
  }

  /**
   * 로컬 스트림 반환
   */
  get localStream(): MediaStream | null {
    return this.localStream;
  }
}