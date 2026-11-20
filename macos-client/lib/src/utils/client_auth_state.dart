import 'dart:convert';

import 'app_logger.dart';
import 'secure_store.dart';

enum ClientAuthStatus { unauthenticated, verifying, verified, localVerified }

class ClientAuthState {
  ClientAuthState({
    required this.authExtension,
    required this.clientKey,
    required this.status,
    required this.failCount,
    this.lastVerifiedAt,
    this.lastError,
  });

  final String authExtension;
  final String clientKey; // 민감
  final ClientAuthStatus status;
  final int failCount;
  final String? lastVerifiedAt;
  final String? lastError;

  static const maxFailCount = 10;

  bool get isVerified =>
      status == ClientAuthStatus.verified ||
      status == ClientAuthStatus.localVerified;
  bool get isOfflineVerified => status == ClientAuthStatus.localVerified;
  bool get isLockedOut => failCount >= maxFailCount && !isVerified;

  ClientAuthState copyWith({
    String? authExtension,
    String? clientKey,
    ClientAuthStatus? status,
    int? failCount,
    String? lastVerifiedAt,
    String? lastError,
    bool clearError = false,
  }) =>
      ClientAuthState(
        authExtension: authExtension ?? this.authExtension,
        clientKey: clientKey ?? this.clientKey,
        status: status ?? this.status,
        failCount: failCount ?? this.failCount,
        lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  static ClientAuthState empty() => ClientAuthState(
        authExtension: '',
        clientKey: '',
        status: ClientAuthStatus.unauthenticated,
        failCount: 0,
      );

  Map<String, dynamic> toPublicJson() => {
        'authExtension': authExtension,
        'hasKey': clientKey.isNotEmpty,
        'status': status.name,
        'failCount': failCount,
        'lastVerifiedAt': lastVerifiedAt,
      };
}

class ClientAuthStore {
  ClientAuthStore._(this._secure);
  static ClientAuthStore? _instance;
  final SecureStore _secure;

  static const _kExt = 'client.auth.extension';
  static const _kKey = 'client.auth.key';
  static const _kState = 'client.auth.state'; // non-sensitive json

  ClientAuthState _state = ClientAuthState.empty();
  ClientAuthState get state => _state;

  static ClientAuthStore instance() {
    _instance ??= ClientAuthStore._(FileSecureStore.instance());
    return _instance!;
  }

  Future<ClientAuthState> load() async {
    try {
      final ext = await _secure.read(_kExt) ?? '';
      final key = await _secure.read(_kKey) ?? '';
      ClientAuthStatus status = ClientAuthStatus.unauthenticated;
      int fail = 0;
      String? lastVerifiedAt;
      final metaRaw = await _secure.read(_kState);
      if (metaRaw != null && metaRaw.isNotEmpty) {
        final meta = jsonDecode(metaRaw) as Map<String, dynamic>;
        status = ClientAuthStatus.values.firstWhere(
          (e) => e.name == (meta['status'] as String?),
          orElse: () => ClientAuthStatus.unauthenticated,
        );
        fail = (meta['failCount'] as num?)?.toInt() ?? 0;
        lastVerifiedAt = meta['lastVerifiedAt'] as String?;
      }
      // 정책: 저장된 verified라도 키/내선 없으면 미인증
      if (ext.isEmpty || key.isEmpty) {
        status = ClientAuthStatus.unauthenticated;
      }
      if (fail >= ClientAuthState.maxFailCount &&
          status != ClientAuthStatus.verified) {
        status = ClientAuthStatus.unauthenticated;
      }
      _state = ClientAuthState(
        authExtension: ext,
        clientKey: key,
        status: status,
        failCount: fail.clamp(0, ClientAuthState.maxFailCount),
        lastVerifiedAt: lastVerifiedAt,
      );
    } catch (e) {
      AppLogger.instance.w('ClientAuthStore load 실패: $e');
      _state = ClientAuthState.empty();
    }
    return _state;
  }

  Future<void> _persist() async {
    await _secure.write(_kExt, _state.authExtension);
    if (_state.clientKey.isEmpty) {
      await _secure.delete(_kKey);
    } else {
      await _secure.write(_kKey, _state.clientKey);
    }
    await _secure.write(
      _kState,
      jsonEncode({
        'status': _state.status.name,
        'failCount': _state.failCount,
        'lastVerifiedAt': _state.lastVerifiedAt,
      }),
    );
  }

  /// 새 입력 적용(Enter 검증 전): 값 교체 + 미검증 상태 전환(정책: 새 입력 시 교체/무효화)
  Future<ClientAuthState> applyInput(
      {required String extension, required String clientKey}) async {
    _state = _state.copyWith(
      authExtension: extension.trim(),
      clientKey: clientKey.trim(),
      status: ClientAuthStatus.verifying,
      clearError: true,
      // failCount 유지? 재시도 누적 의미가 있으나 새 자격이면 0이 자연스러움; 정책상 10회 실패 누적 기준은 검증 실패 시 증가로 처리
    );
    await _persist();
    return _state;
  }

  Future<ClientAuthState> markVerifying() async {
    _state =
        _state.copyWith(status: ClientAuthStatus.verifying, clearError: true);
    await _persist();
    return _state;
  }

  Future<ClientAuthState> markVerified() async {
    _state = _state.copyWith(
      status: ClientAuthStatus.verified,
      failCount: 0,
      lastVerifiedAt: DateTime.now().toUtc().toIso8601String(),
      clearError: true,
    );
    await _persist();
    AppLogger.instance
        .i('OPS client auth verified ext=${_state.authExtension}');
    return _state;
  }

  Future<ClientAuthState> markLocalVerified({String? reason}) async {
    _state = _state.copyWith(
      status: ClientAuthStatus.localVerified,
      failCount: 0,
      lastVerifiedAt: DateTime.now().toUtc().toIso8601String(),
      lastError: reason,
    );
    await _persist();
    AppLogger.instance
        .i('OPS client auth local-verified (offline) ext=${_state.authExtension}');
    return _state;
  }

  /// 검증 실패: 횟수 증가, 10회 도달 시 로컬 인증정보(키/내선) 초기화
  Future<ClientAuthState> markFailed({String? reason}) async {
    final nextFail =
        (_state.failCount + 1).clamp(0, ClientAuthState.maxFailCount);
    if (nextFail >= ClientAuthState.maxFailCount) {
      _state = ClientAuthState(
        authExtension: _state.authExtension,
        clientKey: _state.clientKey,
        status: ClientAuthStatus.unauthenticated,
        failCount: ClientAuthState.maxFailCount,
        lastError: reason ?? '인증 실패가 반복되었습니다. 키/내선은 유지됩니다.',
      );
      await _persist();
      AppLogger.instance.w('OPS client auth locked (credentials kept)');
      return _state;
    }
    _state = _state.copyWith(
      status: ClientAuthStatus.unauthenticated,
      failCount: nextFail,
      lastError: reason,
    );
    await _persist();
    AppLogger.instance.w('OPS client auth failed count=$nextFail');
    return _state;
  }

  /// 정책 초기화: 인증 내선·OPS 키만 초기화(서버 무변경)
  Future<ClientAuthState> resetAuth({String? reason}) async {
    final keepFailNote =
        reason?.contains('10회') == true ? ClientAuthState.maxFailCount : 0;
    _state = ClientAuthState(
      authExtension: '',
      clientKey: '',
      status: ClientAuthStatus.unauthenticated,
      failCount: 0,
      lastError: reason,
    );
    if (keepFailNote == ClientAuthState.maxFailCount) {
      _state = _state.copyWith(failCount: ClientAuthState.maxFailCount);
    }
    await _persist();
    AppLogger.instance.i('OPS client auth locally reset (key/extension only)');
    return _state;
  }
}
