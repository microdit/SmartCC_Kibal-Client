/** @format */

import type { Session } from 'sip.js';
import type { SipSessionInfo, SipSessionState } from '@/types';

/**
 * SipSession — SIP 세션 래퍼
 *
 * 책임:
 * - SIP.js Session 상태 관리
 * - 통화 시작/종료
 * - 미디어 스트림 연결/분리
 *
 * @author  Kibal Team
 * @version 1.0.0
 * @since   2026-10-29
 */
export class SipSession {
  private _session: Session;
  private _sessionInfo: SipSessionInfo;

  constructor(session: Session) {
    this._session = session;
    this._sessionInfo = {
      id: session.id,
      state: 'new',
      remoteIdentity: {
        name: '',
        uri: session.request?.from?.uri?.toString() || '',
      },
      isOriginating: false,
    };

    // 세션 상태 변경 감지
    session.on('progress', () => {
      this._sessionInfo.state = 'ringing';
    });
    session.on('accepted', () => {
      this._sessionInfo.state = 'active';
    });
    session.on('terminated', () => {
      this._sessionInfo.state = 'terminated';
    });
    session.on('failed', () => {
      this._sessionInfo.state = 'failed';
    });
  }

  get session(): Session {
    return this._session;
  }

  get id(): string {
    return this._session.id;
  }

  get state(): SipSessionState {
    return this._sessionInfo.state;
  }

  get info(): SipSessionInfo {
    return this._sessionInfo;
  }

  get isOriginating(): boolean {
    return this._sessionInfo.isOriginating;
  }

  get remoteIdentity(): { name: string; uri: string } {
    return this._sessionInfo.remoteIdentity;
  }

  /**
   * 통화 수락
   */
  async accept(): Promise<void> {
    await this._session.accept();
    this._sessionInfo.state = 'active';
  }

  /**
   * 통화 종료
   */
  async terminate(): Promise<void> {
    await this._session.terminate();
    this._sessionInfo.state = 'terminated';
  }

  /**
   * 세션 정리
   */
  dispose(): void {
    // 필요시 정리 작업
  }
}