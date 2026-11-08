import {
  Invitation,
  Inviter,
  Registerer,
  RegistererState,
  Session,
  SessionState,
  UserAgent,
  Web
} from "sip.js";
import type { UserAgentOptions } from "sip.js";
import type { SipConfig } from "../config";

export interface SipClientCallbacks {
  onLog?: (message: string) => void;
  onRegistration?: (state: string, detail?: string) => void;
  onIncoming?: (invitation: Invitation) => void;
  onSessionState?: (state: SessionState, session: Session) => void;
}

export interface LocalMediaState {
  audio: boolean;
  video: boolean;
}

const mediaConstraints: MediaStreamConstraints = {
  audio: true,
  video: { width: { ideal: 1280 }, height: { ideal: 720 } }
};

const CONNECT_TIMEOUT_MS = 15000;
const DISCONNECT_TIMEOUT_MS = 5000;

export class KibalSipClient {
  private ua?: UserAgent;
  private registerer?: Registerer;
  private config?: SipConfig;
  private currentSession?: Session;
  private shuttingDown = false;
  private readonly callbacks: SipClientCallbacks;

  constructor(callbacks: SipClientCallbacks = {}) {
    this.callbacks = callbacks;
  }

  get session(): Session | undefined {
    return this.currentSession;
  }

  get connected(): boolean {
    return Boolean(this.ua);
  }

  async connect(config: SipConfig): Promise<void> {
    if (this.ua) {
      throw new Error("이미 연결되어 있습니다.");
    }

    const uri = UserAgent.makeURI(`sip:${config.username}@${config.domain}`);
    if (!uri) {
      throw new Error(`잘못된 SIP URI: ${config.username}@${config.domain}`);
    }

    this.config = config;
    this.shuttingDown = false;
    this.log(`connecting ${config.wsServer} as ${config.username}`);
    this.callbacks.onRegistration?.("connecting");

    const options: UserAgentOptions = {
      uri,
      authorizationUsername: config.username,
      authorizationPassword: config.password,
      displayName: config.displayName,
      logLevel: "debug",
      logBuiltinEnabled: false,
      transportOptions: {
        server: config.wsServer,
        traceSip: true
      },
      sessionDescriptionHandlerFactory: createSfuSessionDescriptionHandlerFactory(),
      sessionDescriptionHandlerFactoryOptions: {
        peerConnectionConfiguration: {
          iceServers: config.iceServers.map((urls) => ({ urls }))
        }
      },
      delegate: {
        onConnect: () => {
          this.log("WebSocket connected");
          this.callbacks.onRegistration?.("connected");
        },
        onDisconnect: (error) => {
          this.log(`WebSocket disconnected${error ? `: ${error.message}` : ""}`);
          if (!this.shuttingDown) {
            this.callbacks.onRegistration?.(
              "disconnected",
              error?.message ?? "WebSocket 연결이 종료되었습니다."
            );
          }
        },
        onInvite: (invitation) => {
          if (this.currentSession) {
            this.log("busy: rejecting additional incoming call");
            void invitation.reject().catch((error) => {
              this.log(`busy reject failed: ${errorMessage(error)}`);
            });
            return;
          }
          this.log(`incoming call from ${invitation.remoteIdentity.uri.toString()}`);
          this.bindSession(invitation);
          this.callbacks.onIncoming?.(invitation);
        }
      },
      logConnector: (level, category, label, content) => {
        if (level === "warn" || level === "error") {
          this.log(`[${level}] ${category}${label ? ` ${label}` : ""}: ${content}`);
        }
      }
    };

    this.ua = new UserAgent(options);
    try {
      await withTimeout(
        this.ua.start(),
        CONNECT_TIMEOUT_MS,
        "WebSocket 연결 시간 초과"
      );

      this.registerer = new Registerer(this.ua);
      this.registerer.stateChange.addListener((state) => {
        this.log(`registration ${state}`);
        this.callbacks.onRegistration?.(state.toLowerCase());
      });
      await withTimeout(
        this.registerer.register(),
        CONNECT_TIMEOUT_MS,
        "SIP REGISTER 응답 시간 초과"
      );
      await waitForRegistered(this.registerer, CONNECT_TIMEOUT_MS);
    } catch (error) {
      await this.stopTransport();
      throw new Error(`SIP 연결 실패: ${errorMessage(error)}`);
    }
  }

  async disconnect(): Promise<void> {
    this.shuttingDown = true;
    try {
      if (this.registerer?.state === RegistererState.Registered) {
        await withTimeout(
          this.registerer.unregister(),
          DISCONNECT_TIMEOUT_MS,
          "SIP 등록 해제 시간 초과"
        );
      }
    } catch (error) {
      this.log(`unregister failed: ${errorMessage(error)}`);
    }
    await this.stopTransport();
  }

  async call(target: string): Promise<void> {
    if (!this.ua || !this.config) {
      throw new Error("먼저 SIP 등록을 완료하세요.");
    }
    if (this.currentSession) {
      throw new Error("이미 진행 중인 통화가 있습니다.");
    }
    const normalizedTarget = target.trim();
    if (!normalizedTarget) {
      throw new Error("대상 번호를 입력하세요.");
    }
    const destination = UserAgent.makeURI(`sip:${normalizedTarget}@${this.config.domain}`);
    if (!destination) {
      throw new Error(`잘못된 대상 번호: ${normalizedTarget}`);
    }

    this.log(`calling ${normalizedTarget}`);
    const inviter = new Inviter(this.ua, destination, {
      sessionDescriptionHandlerOptions: { constraints: mediaConstraints }
    });
    this.bindSession(inviter);
    await inviter.invite();
  }

  async accept(invitation: Invitation): Promise<void> {
    this.log("accepting incoming call");
    this.bindSession(invitation);
    await invitation.accept({
      sessionDescriptionHandlerOptions: { constraints: mediaConstraints }
    });
  }

  async reject(invitation: Invitation): Promise<void> {
    this.log("rejecting incoming call");
    await invitation.reject();
  }

  async hangup(): Promise<void> {
    const session = this.currentSession;
    if (!session) {
      return;
    }
    this.log(`hangup (${session.state})`);
    if (session instanceof Inviter && session.state !== SessionState.Established) {
      await session.cancel();
      return;
    }
    if (session instanceof Invitation && session.state !== SessionState.Established) {
      await session.reject();
      return;
    }
    await session.bye();
  }

  setAudioEnabled(enabled: boolean): LocalMediaState {
    return this.setMediaEnabled("audio", enabled);
  }

  setVideoEnabled(enabled: boolean): LocalMediaState {
    return this.setMediaEnabled("video", enabled);
  }

  getMediaState(): LocalMediaState {
    const tracks = this.getLocalTracks();
    return {
      audio: Boolean(tracks.find((track) => track.kind === "audio" && track.enabled)),
      video: Boolean(tracks.find((track) => track.kind === "video" && track.enabled))
    };
  }

  private setMediaEnabled(
    kind: "audio" | "video",
    enabled: boolean
  ): LocalMediaState {
    this.getLocalTracks()
      .filter((track) => track.kind === kind)
      .forEach((track) => {
        track.enabled = enabled;
      });
    return this.getMediaState();
  }

  private getLocalTracks(): MediaStreamTrack[] {
    const peerConnection = this.peerConnection();
    if (!peerConnection) {
      return [];
    }
    return peerConnection
      .getSenders()
      .map((sender) => sender.track)
      .filter((track): track is MediaStreamTrack => Boolean(track));
  }

  private peerConnection(): RTCPeerConnection | undefined {
    return (
      this.currentSession?.sessionDescriptionHandler as
        | { peerConnection?: RTCPeerConnection }
        | undefined
    )?.peerConnection;
  }

  private bindSession(session: Session): void {
    this.currentSession = session;
    this.callbacks.onSessionState?.(session.state, session);
    session.stateChange.addListener((state) => {
      this.callbacks.onSessionState?.(state, session);
      if (state === SessionState.Terminated && this.currentSession === session) {
        this.currentSession = undefined;
      }
    });
  }

  private async stopTransport(): Promise<void> {
    try {
      await withTimeout(
        this.ua?.stop() ?? Promise.resolve(),
        DISCONNECT_TIMEOUT_MS,
        "SIP 종료 시간 초과"
      );
    } catch (error) {
      this.log(`transport stop failed: ${errorMessage(error)}`);
    }
    this.registerer = undefined;
    this.ua = undefined;
    this.currentSession = undefined;
    this.callbacks.onRegistration?.("idle");
  }

  private log(message: string): void {
    this.callbacks.onLog?.(message);
  }
}

export function attachMedia(
  session: Session,
  localVideo: HTMLVideoElement | null,
  onRemoteStreams?: (streams: MediaStream[]) => void
): () => void {
  const handler = session.sessionDescriptionHandler as
    | { peerConnection?: RTCPeerConnection }
    | undefined;
  const peerConnection = handler?.peerConnection;
  if (!peerConnection) {
    return () => undefined;
  }

  if (new URLSearchParams(window.location.search).has("debug")) {
    (window as unknown as { __kibalPC?: RTCPeerConnection }).__kibalPC = peerConnection;
  }

  const videoStreams = new Map<string, MediaStream>();
  const audioOnlyStream = new MediaStream();
  let lastStreams: MediaStream[] = [];
  let stopped = false;
  let syncInterval: number | undefined;
  const syncTimers: number[] = [];

  const syncRemote = (): void => {
    if (stopped) {
      return;
    }
    const tracks = peerConnection
      .getReceivers()
      .map((receiver) => receiver.track)
      .filter((track): track is MediaStreamTrack => Boolean(track) && track.readyState === "live");
    const audioTracks = tracks.filter((track) => track.kind === "audio");
    const videoTracks = tracks.filter((track) => track.kind === "video" && !track.muted);
    const activeVideoIds = new Set(videoTracks.map((track) => track.id));

    videoStreams.forEach((_, trackId) => {
      if (!activeVideoIds.has(trackId)) {
        videoStreams.delete(trackId);
      }
    });

    const streams = videoTracks.map((track) => {
      let stream = videoStreams.get(track.id);
      if (!stream) {
        stream = new MediaStream([track]);
        videoStreams.set(track.id, stream);
      }
      return stream;
    });

    if (streams.length === 0) {
      syncAudioTracks(audioOnlyStream, audioTracks);
      const nextStreams = audioOnlyStream.getTracks().length > 0 ? [audioOnlyStream] : [];
      if (!sameStreams(nextStreams, lastStreams)) {
        lastStreams = nextStreams;
        onRemoteStreams?.(nextStreams);
      }
      return;
    }

    streams.forEach((stream, index) => {
      if (index === 0) {
        syncAudioTracks(stream, audioTracks);
      } else {
        stream.getAudioTracks().forEach((track) => stream.removeTrack(track));
      }
    });

    if (!sameStreams(streams, lastStreams)) {
      lastStreams = streams;
      onRemoteStreams?.(streams);
    }
  };

  const watchedTracks = new WeakSet<MediaStreamTrack>();
  const watchTrack = (track: MediaStreamTrack): void => {
    if (watchedTracks.has(track)) {
      return;
    }
    watchedTracks.add(track);
    track.addEventListener("mute", syncRemote);
    track.addEventListener("unmute", syncRemote);
    track.addEventListener("ended", syncRemote);
  };

  const onTrack = (event: RTCTrackEvent): void => {
    watchTrack(event.track);
    syncRemote();
  };

  const cleanup = (): void => {
    if (stopped) {
      return;
    }
    stopped = true;
    if (syncInterval !== undefined) {
      window.clearInterval(syncInterval);
    }
    syncTimers.forEach((timer) => window.clearTimeout(timer));
    peerConnection.removeEventListener("track", onTrack);
    peerConnection.removeEventListener("connectionstatechange", onConnectionStateChange);
  };

  const onConnectionStateChange = (): void => {
    if (
      peerConnection.connectionState === "closed" ||
      peerConnection.connectionState === "failed"
    ) {
      cleanup();
    }
  };

  peerConnection.getReceivers().forEach((receiver) => {
    if (receiver.track) {
      watchTrack(receiver.track);
    }
  });
  peerConnection.addEventListener("track", onTrack);
  peerConnection.addEventListener("connectionstatechange", onConnectionStateChange);

  syncRemote();
  syncTimers.push(window.setTimeout(syncRemote, 500));
  syncTimers.push(window.setTimeout(syncRemote, 1500));
  syncInterval = window.setInterval(syncRemote, 1000);

  if (localVideo) {
    const localStream = new MediaStream(
      peerConnection
        .getSenders()
        .map((sender) => sender.track)
        .filter((track): track is MediaStreamTrack => Boolean(track))
    );
    localVideo.srcObject = localStream;
    void localVideo.play().catch(() => undefined);
  }

  return cleanup;
}

function waitForRegistered(registerer: Registerer, timeoutMs: number): Promise<void> {
  if (registerer.state === RegistererState.Registered) {
    return Promise.resolve();
  }
  return withTimeout(
    new Promise<void>((resolve, reject) => {
      const listener = (state: RegistererState): void => {
        if (state === RegistererState.Registered) {
          registerer.stateChange.removeListener(listener);
          resolve();
          return;
        }
        if (state === RegistererState.Unregistered || state === RegistererState.Terminated) {
          registerer.stateChange.removeListener(listener);
          reject(new Error("SIP 등록이 거부되었습니다. 내선·비밀번호·서버 주소를 확인하세요."));
        }
      };
      registerer.stateChange.addListener(listener);
    }),
    timeoutMs,
    "SIP 등록 상태 확인 시간 초과"
  );
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number, message: string): Promise<T> {
  let timer: number | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = window.setTimeout(() => reject(new Error(message)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => {
    if (timer !== undefined) {
      window.clearTimeout(timer);
    }
  });
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

type SfuSessionDescriptionHandler = {
  remoteMediaStream: MediaStream;
  setRemoteTrack: (track: MediaStreamTrack) => void;
};

function createSfuSessionDescriptionHandlerFactory(): NonNullable<UserAgentOptions["sessionDescriptionHandlerFactory"]> {
  const factory = Web.defaultSessionDescriptionHandlerFactory();
  return (session, options) => {
    const handler = factory(session, options);
    const sfuHandler = handler as unknown as SfuSessionDescriptionHandler;
    const setRemoteTrack = sfuHandler.setRemoteTrack.bind(handler);
    sfuHandler.setRemoteTrack = (track) => {
      if (track.kind !== "video") {
        setRemoteTrack(track);
        return;
      }
      const remoteStream = sfuHandler.remoteMediaStream;
      if (remoteStream.getTrackById(track.id)) {
        return;
      }
      remoteStream.addTrack(track);
      remoteStream.dispatchEvent(new MediaStreamTrackEvent("addtrack", { track }));
    };
    return handler;
  };
}

function syncAudioTracks(stream: MediaStream, audioTracks: MediaStreamTrack[]): void {
  const activeIds = new Set(audioTracks.map((track) => track.id));
  stream.getAudioTracks().forEach((track) => {
    if (!activeIds.has(track.id)) {
      stream.removeTrack(track);
    }
  });
  const currentIds = new Set(stream.getAudioTracks().map((track) => track.id));
  audioTracks.forEach((track) => {
    if (!currentIds.has(track.id)) {
      stream.addTrack(track);
    }
  });
}

function sameStreams(left: MediaStream[], right: MediaStream[]): boolean {
  return left.length === right.length && left.every((stream, index) => stream === right[index]);
}
