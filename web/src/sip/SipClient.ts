import {
  Invitation,
  Inviter,
  Registerer,
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

const mediaConstraints: MediaStreamConstraints = {
  audio: true,
  video: { width: { ideal: 1280 }, height: { ideal: 720 } }
};

export class KibalSipClient {
  private ua?: UserAgent;
  private registerer?: Registerer;
  private config?: SipConfig;
  private currentSession?: Session;
  private readonly callbacks: SipClientCallbacks;

  constructor(callbacks: SipClientCallbacks = {}) {
    this.callbacks = callbacks;
  }

  get session(): Session | undefined {
    return this.currentSession;
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
          this.callbacks.onRegistration?.("disconnected");
        },
        onInvite: (invitation) => {
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
    await this.ua.start();

    this.registerer = new Registerer(this.ua);
    this.registerer.stateChange.addListener((state) => {
      this.log(`registration ${state}`);
      this.callbacks.onRegistration?.(state.toLowerCase());
    });
    await this.registerer.register();
  }

  async disconnect(): Promise<void> {
    try {
      await this.registerer?.unregister();
    } catch (error) {
      this.log(`unregister failed: ${errorMessage(error)}`);
    }
    await this.ua?.stop();
    this.registerer = undefined;
    this.ua = undefined;
    this.currentSession = undefined;
    this.callbacks.onRegistration?.("idle");
  }

  async call(target: string): Promise<void> {
    if (!this.ua || !this.config) {
      throw new Error("먼저 SIP 등록을 완료하세요.");
    }
    const destination = UserAgent.makeURI(`sip:${target}@${this.config.domain}`);
    if (!destination) {
      throw new Error(`잘못된 대상 번호: ${target}`);
    }

    this.log(`calling ${target}`);
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

  private log(message: string): void {
    this.callbacks.onLog?.(message);
  }
}

export function attachMedia(
  session: Session,
  localVideo: HTMLVideoElement | null,
  onRemoteStreams?: (streams: MediaStream[]) => void
): void {
  const handler = session.sessionDescriptionHandler as
    | { peerConnection?: RTCPeerConnection }
    | undefined;
  const peerConnection = handler?.peerConnection;
  if (!peerConnection) {
    return;
  }

  if (new URLSearchParams(window.location.search).has("debug")) {
    (window as unknown as { __kibalPC?: RTCPeerConnection }).__kibalPC = peerConnection;
  }

  const videoStreams = new Map<string, MediaStream>();
  const audioOnlyStream = new MediaStream();
  let lastStreams: MediaStream[] = [];

  const syncRemote = (): void => {
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

  peerConnection.getReceivers().forEach((receiver) => {
    if (receiver.track) {
      watchTrack(receiver.track);
    }
  });
  peerConnection.addEventListener("track", (event) => {
    watchTrack(event.track);
    syncRemote();
  });

  syncRemote();
  window.setTimeout(syncRemote, 500);
  window.setTimeout(syncRemote, 1500);
  const syncInterval = window.setInterval(syncRemote, 1000);
  peerConnection.addEventListener("connectionstatechange", () => {
    if (peerConnection.connectionState === "closed" || peerConnection.connectionState === "failed") {
      window.clearInterval(syncInterval);
    }
  });

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
