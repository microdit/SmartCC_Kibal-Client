import { useEffect, useRef, useState } from "react";
import type { Invitation } from "sip.js";
import { SessionState, type Session } from "sip.js";
import { defaultConfig, loadStoredConfig, saveStoredConfig } from "./config";
import type { SipConfig } from "./config";
import { attachMedia, KibalSipClient } from "./sip/SipClient";

type CallState = "idle" | "incoming" | SessionState;

const REGISTRATION_LABEL: Record<string, string> = {
  idle: "미등록",
  connecting: "연결 중",
  connected: "WebSocket 연결됨",
  registered: "등록됨",
  unregistered: "미등록",
  terminated: "종료됨",
  disconnected: "연결 끊김"
};

export default function App() {
  const [config, setConfig] = useState<SipConfig>(() => loadStoredConfig());
  const [registration, setRegistration] = useState("idle");
  const [callState, setCallState] = useState<CallState>("idle");
  const [incoming, setIncoming] = useState<Invitation | null>(null);
  const [target, setTarget] = useState("1102");
  const [logs, setLogs] = useState<string[]>([]);
  const [error, setError] = useState("");
  const [remoteStreams, setRemoteStreams] = useState<MediaStream[]>([]);

  const clientRef = useRef<KibalSipClient | null>(null);
  const localVideoRef = useRef<HTMLVideoElement | null>(null);

  const appendLog = (message: string): void => {
    const line = `${new Date().toLocaleTimeString()} ${message}`;
    setLogs((current) => [...current.slice(-299), line]);
  };

  const handleSessionState = (state: SessionState, session: Session): void => {
    setCallState(state);
    if (state === SessionState.Established) {
      window.setTimeout(() => {
        attachMedia(session, localVideoRef.current, setRemoteStreams);
      }, 100);
      return;
    }
    if (state === SessionState.Terminated) {
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = null;
      }
      setRemoteStreams([]);
      setIncoming(null);
    }
  };

  const handleConnect = async (): Promise<void> => {
    setError("");
    const client = new KibalSipClient({
      onLog: appendLog,
      onRegistration: setRegistration,
      onIncoming: (invitation) => {
        setIncoming(invitation);
        setCallState("incoming");
      },
      onSessionState: handleSessionState
    });
    try {
      await client.connect({ ...config, displayName: `Kibal ${config.username}` });
      clientRef.current = client;
      saveStoredConfig(config);
    } catch (connectError) {
      setError(toMessage(connectError));
      await client.disconnect().catch(() => undefined);
    }
  };

  const handleDisconnect = async (): Promise<void> => {
    setError("");
    await clientRef.current?.disconnect();
    clientRef.current = null;
    setCallState("idle");
    setIncoming(null);
  };

  const handleCall = async (destination: string): Promise<void> => {
    setError("");
    try {
      await clientRef.current?.call(destination);
    } catch (callError) {
      setError(toMessage(callError));
    }
  };

  const handleAccept = async (): Promise<void> => {
    if (!incoming) {
      return;
    }
    setError("");
    try {
      await clientRef.current?.accept(incoming);
      setIncoming(null);
    } catch (acceptError) {
      setError(toMessage(acceptError));
    }
  };

  const handleReject = async (): Promise<void> => {
    if (!incoming) {
      return;
    }
    await clientRef.current?.reject(incoming);
    setIncoming(null);
    setCallState("idle");
  };

  const handleHangup = async (): Promise<void> => {
    setError("");
    try {
      await clientRef.current?.hangup();
    } catch (hangupError) {
      setError(toMessage(hangupError));
    }
  };

  const registered = registration === "registered";
  const inCall = callState !== "idle" && callState !== SessionState.Terminated;

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>Kibal Web Client</h1>
          <p>SIP.js + WebRTC 테스트 클라이언트</p>
        </div>
        <span className={`pill ${registered ? "ok" : registration === "connecting" ? "warn" : "off"}`}>
          {REGISTRATION_LABEL[registration] ?? registration}
        </span>
      </header>

      <main className="grid">
        <section className="card">
          <h2>SIP 연결</h2>
          <label>
            서버 도메인
            <input
              value={config.domain}
              disabled={registered}
              onChange={(event) => setConfig({ ...config, domain: event.target.value })}
            />
          </label>
          <label>
            WebSocket URL
            <input
              value={config.wsServer}
              disabled={registered}
              onChange={(event) => setConfig({ ...config, wsServer: event.target.value })}
            />
          </label>
          <div className="row">
            <label>
              내선
              <input
                value={config.username}
                disabled={registered}
                onChange={(event) => setConfig({ ...config, username: event.target.value })}
              />
            </label>
            <label>
              비밀번호
              <input
                type="password"
                value={config.password}
                disabled={registered}
                onChange={(event) => setConfig({ ...config, password: event.target.value })}
              />
            </label>
          </div>
          <label>
            STUN/TURN (쉼표 구분)
            <input
              value={config.iceServers.join(", ")}
              disabled={registered}
              onChange={(event) =>
                setConfig({
                  ...config,
                  iceServers: event.target.value
                    .split(",")
                    .map((value) => value.trim())
                    .filter(Boolean)
                })
              }
            />
          </label>
          <div className="row">
            {!registered ? (
              <button className="primary" onClick={handleConnect} disabled={!config.password}>
                등록
              </button>
            ) : (
              <button onClick={handleDisconnect}>등록 해제</button>
            )}
            <button
              onClick={() => {
                setConfig({ ...defaultConfig, password: config.password });
              }}
              disabled={registered}
            >
              기본값
            </button>
          </div>
        </section>

        <section className="card">
          <h2>통화</h2>
          <div className="row">
            <input
              value={target}
              onChange={(event) => setTarget(event.target.value)}
              placeholder="내선 또는 6000"
            />
            <button className="primary" onClick={() => handleCall(target)} disabled={!registered || inCall}>
              호출
            </button>
          </div>
          <div className="row">
            <button onClick={() => handleCall("6000")} disabled={!registered || inCall}>
              회의실 6000 참가
            </button>
            <button className="danger" onClick={handleHangup} disabled={!inCall}>
              통화 종료
            </button>
          </div>
          <p className="state">세션 상태: {callState}</p>
          {incoming && (
            <div className="incoming">
              <span>수신: {incoming.remoteIdentity.uri.toString()}</span>
              <div className="row">
                <button className="primary" onClick={handleAccept}>
                  받기
                </button>
                <button onClick={handleReject}>거절</button>
              </div>
            </div>
          )}
          {error && <p className="error">{error}</p>}
        </section>
      </main>

      <section className="videos">
        <div className="remote-grid">
          {remoteStreams.length === 0 ? (
            <div className="video remote placeholder">
              <span>원격</span>
            </div>
          ) : (
            remoteStreams.map((stream, index) => (
              <RemoteVideo key={index} stream={stream} index={index} />
            ))
          )}
        </div>
        <div className="video local">
          <video ref={localVideoRef} autoPlay playsInline muted />
          <span>로컬</span>
        </div>
      </section>

      <details className="logs">
        <summary>SIP 로그 ({logs.length})</summary>
        <pre>{logs.join("\n")}</pre>
      </details>
    </div>
  );
}

function RemoteVideo({ stream, index }: { stream: MediaStream; index: number }): JSX.Element {
  const videoRef = useRef<HTMLVideoElement | null>(null);

  useEffect(() => {
    if (videoRef.current) {
      videoRef.current.srcObject = stream;
      void videoRef.current.play().catch(() => undefined);
    }
  }, [stream]);

  return (
    <div className="video remote">
      <video ref={videoRef} autoPlay playsInline />
      <span>원격 {index + 1}</span>
    </div>
  );
}

function toMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
