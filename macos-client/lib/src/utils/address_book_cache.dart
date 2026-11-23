import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'ops_directory.dart';
import 'server_config.dart';

/// 주소록 로컬 캐시(버전관리).
///
/// - 성공적으로 서버에서 받은 유효 주소록만 저장한다.
/// - 네트워크 실패로 기존 캐시를 덮어쓰지 않는다.
/// - 서버 directory_version/force_version 비교로 사용자 갱신/강제 갱신을 판단한다.
class AddressBookCache {
  AddressBookCache({
    required this.directory,
    required this.directoryVersion,
    required this.fetchedAt,
    required this.forceVersion,
    required this.source,
  });

  final OpsDirectory directory;
  final String directoryVersion;
  final DateTime fetchedAt;
  final String forceVersion;
  final String source;

  static String get filePath => '${AppLogger.logDirectory}/address-book-cache.json';

  bool get hasData => directory.contacts.isNotEmpty || directory.rooms.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'fetchedAt': fetchedAt.toIso8601String(),
        'directoryVersion': directoryVersion,
        'forceVersion': forceVersion,
        'source': source,
        'contacts': [
          for (final c in directory.contacts)
            {
              'extension': c.extension,
              'display_name': c.displayName,
              'speed_dial_order': c.sortOrder,
              // SIP 비밀번호는 캐시에 저장하지 않는다(보안/회전 대응). 필요 시 인증된 fetch로 갱신.
            }
        ],
        'rooms': [
          for (final r in directory.rooms)
            {
              'room': r.room,
              'name': r.name,
              'mode': r.mode,
              'sort_order': r.sortOrder,
            }
        ],
      };

  static AddressBookCache? load() {
    try {
      final f = File(filePath);
      if (!f.existsSync()) return null;
      final j = jsonDecode(f.readAsStringSync());
      if (j is! Map<String, dynamic>) return null;
      final contacts = <OpsContact>[];
      for (final e in (j['contacts'] as List? ?? const [])) {
        if (e is! Map) continue;
        final ext = (e['extension'] ?? '').toString();
        if (ext.isEmpty) continue;
        contacts.add(OpsContact(
          extension: ext,
          displayName: (e['display_name'] ?? '').toString(),
          sortOrder: (e['speed_dial_order'] as num?)?.toInt(),
        ));
      }
      final rooms = <OpsRoom>[];
      for (final e in (j['rooms'] as List? ?? const [])) {
        if (e is! Map) continue;
        final room = (e['room'] ?? '').toString();
        if (room.isEmpty) continue;
        rooms.add(OpsRoom(
          room: room,
          name: (e['name'] ?? '').toString(),
          mode: (e['mode'] ?? 'sfu').toString(),
          sortOrder: (e['sort_order'] as num?)?.toInt(),
        ));
      }
      final dir = OpsDirectory(contacts: contacts, rooms: rooms);
      final fetchedAt = DateTime.tryParse((j['fetchedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return AddressBookCache(
        directory: dir,
        directoryVersion: (j['directoryVersion'] ?? '').toString(),
        fetchedAt: fetchedAt,
        forceVersion: (j['forceVersion'] ?? '').toString(),
        source: (j['source'] ?? 'cache').toString(),
      );
    } catch (e) {
      AppLogger.instance.w('AddressBookCache load failed: $e');
      return null;
    }
  }

  void save() {
    try {
      File(filePath).writeAsStringSync(jsonEncode(toJson()));
    } catch (e) {
      AppLogger.instance.w('AddressBookCache save failed: $e');
    }
  }

  static void clear() {
    try {
      final f = File(filePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

class AddressBookSyncDecision {
  AddressBookSyncDecision({
    required this.shouldFetch,
    required this.reason,
    required this.remoteVersion,
    required this.forceUpdate,
    required this.forceVersion,
  });
  final bool shouldFetch;
  final String reason;
  final String remoteVersion;
  final bool forceUpdate;
  final String forceVersion;
}

/// 서버 버전 메타(OPS /api/client/config manifest)에서 주소록 갱신 필요 여부 판단.
class AddressBookVersionPolicy {
  static String remoteVersion(ServerConfig cfg) {
    final m = cfg.manifest;
    final v = (m?['directory_version'] ?? m?['config_version'] ?? cfg.configVersion ?? '')
        .toString();
    return v.trim();
  }

  static String remoteForceVersion(ServerConfig cfg) {
    final m = cfg.manifest;
    return (m?['force_version'] ?? '').toString().trim();
  }

  static bool remoteForceUpdate(ServerConfig cfg) {
    final m = cfg.manifest;
    return m?['force_update'] == true;
  }

  static AddressBookSyncDecision decide({
    required AddressBookCache? cache,
    required ServerConfig cfg,
    required bool userRequested,
  }) {
    final remote = remoteVersion(cfg);
    final force = remoteForceUpdate(cfg);
    final forceV = remoteForceVersion(cfg);
    final hasCache = cache != null && cache.hasData;

    if (!hasCache) {
      return AddressBookSyncDecision(
          shouldFetch: true,
          reason: 'no-cache',
          remoteVersion: remote,
          forceUpdate: force,
          forceVersion: forceV);
    }
    if (force && forceV.isNotEmpty && cache.forceVersion != forceV) {
      return AddressBookSyncDecision(
          shouldFetch: true,
          reason: 'force-update',
          remoteVersion: remote,
          forceUpdate: true,
          forceVersion: forceV);
    }
    if (userRequested) {
      return AddressBookSyncDecision(
          shouldFetch: true,
          reason: 'user-requested',
          remoteVersion: remote,
          forceUpdate: force,
          forceVersion: forceV);
    }
    if (remote.isNotEmpty && cache.directoryVersion.isNotEmpty && remote != cache.directoryVersion) {
      return AddressBookSyncDecision(
          shouldFetch: false,
          reason: 'update-available',
          remoteVersion: remote,
          forceUpdate: force,
          forceVersion: forceV);
    }
    if (remote.isNotEmpty && cache.directoryVersion.isEmpty) {
      // 구캐시(버전 없음)는 비교 불가: 조용히 유지, 사용자가 갱신 가능.
      return AddressBookSyncDecision(
          shouldFetch: false,
          reason: 'cache-no-version',
          remoteVersion: remote,
          forceUpdate: force,
          forceVersion: forceV);
    }
    return AddressBookSyncDecision(
        shouldFetch: false,
        reason: 'up-to-date',
        remoteVersion: remote,
        forceUpdate: force,
        forceVersion: forceV);
  }
}
