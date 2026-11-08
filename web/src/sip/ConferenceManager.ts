/** @format */

import type { Session, UserAgent } from 'sip.js';
import type { SipConfig, ConfParticipant } from '@/types';
import { MediaManager } from './MediaManager';
import { SipSession } from './SipSession';

/**
 * ConferenceManager — ConfBridge 회의실 참여/퇴장 관리
 *
 * 책임:
 * - 회의실(6000번) INVITE 참여
 * - 참여자 미디어 스트림 관리 (SFU 모델)
 * - 격자 레이아웃 스트림 매핑
 * - 회의 퇴장
 *
 * @author  Kibal Team
 * @version 1.0.0
 * @since   2026-10-29
 */
export class ConferenceManager {
  private config: SipConfig;
  private mediaManager: MediaManager;
  private conferenceId: string = '6000';
  private participantStreams: Map<string, MediaStream> = new Map();
  private currentSession: SipSession | null = null;
  private localStream: MediaStream | null = null;

  constructor(config: SipConfig, mediaManager: MediaManager) {
    this.config = config;
    this.mediaManager = mediaManager;
  }

  /**
   * 회의실 참여
   * @param displayName 참가자 표시명
   * @param onParticipantJoined 참가자 입장 콜백
   * @param onTrackAdded 원격 트랙 수신 콜백
   */
  async joinConference(
    displayName: string,
    onParticipantJoined: (participant: ConfParticipant) => void,
    onTrackAdded: (participantId: string, track: MediaStreamTrack, stream: MediaStream) => void
  ): Promise<SipSession> {
    void this.config; // SIP 설정 참조 (placeholder — 회의실 INVITE는 KibalSipClient에서 처리)
    // SIP.js UserAgent에서 INVITE 발신
    // 이 메서드는 KibalSipClient와 협업하여 호출됨
    throw new Error('Use KibalSipClient.makeCall() with conference ID');
  }

  /**
   * 회의실에서 퇴장
   */
  async leaveConference(): Promise<void> {
    if (this.currentSession) {
      await this.currentSession.terminate();
      this.currentSession = null;
    }

    // 참가자 스트림 정리
    this.participantStreams.forEach((stream) => {
      stream.getTracks().forEach((track) => track.stop());
    });
    this.participantStreams.clear();
    this.localStream = null;
  }

  /**
   * 참가자 스트림 추가
   */
  addParticipantStream(participantId: string, stream: MediaStream): void {
    this.participantStreams.set(participantId, stream);
  }

  /**
   * 참가자 스트림 제거
   */
  removeParticipantStream(participantId: string): void {
    const stream = this.participantStreams.get(participantId);
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
      this.participantStreams.delete(participantId);
    }
  }

  /**
   * 모든 참가자 스트림 반환
   */
  get participantStreams(): Map<string, MediaStream> {
    return this.participantStreams;
  }

  /**
   * 회의실 ID 설정
   */
  setConferenceId(id: string): void {
    this.conferenceId = id;
  }

  /**
   * 회의실 ID 반환
   */
  getConferenceId(): string {
    return this.conferenceId;
  }

  /**
   * 참가자 목록 반환 (최대 4명)
   */
  getParticipants(): ConfParticipant[] {
    const participants: ConfParticipant[] = [];
    this.participantStreams.forEach((stream, id) => {
      participants.push({
        id,
        name: id,
        stream,
        isActive: true,
      });
    });
    return participants.slice(0, 4);
  }

  /**
   * 정리
   */
  dispose(): void {
    this.leaveConference().catch(() => {});
  }
}