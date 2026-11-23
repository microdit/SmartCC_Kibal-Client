import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'constants.dart';
import 'server_config.dart';

class OpsContact {
  OpsContact(
      {required this.extension,
      required this.displayName,
      this.sortOrder,
      this.sipPassword});
  final String extension;
  final String displayName;
  final int? sortOrder;
  // Ops 웹에서 설정/수정한 SIP 비밀번호(인증된 /api/client/contacts 응답, 바로 접속 동기화용)
  final String? sipPassword;

  String get label => displayName.isNotEmpty && displayName != extension
      ? '$extension $displayName'
      : extension;
}

class OpsRoom {
  OpsRoom(
      {required this.room,
      required this.name,
      required this.mode,
      this.sortOrder});
  final String room;
  final String name;
  final String mode;
  final int? sortOrder;
}

class OpsDirectory {
  const OpsDirectory({this.contacts = const [], this.rooms = const []});
  final List<OpsContact> contacts;
  final List<OpsRoom> rooms;

  static const _timeout = Duration(seconds: 4);

  /// 성공 시 [OpsDirectoryFetch.ok], 실패 시 [OpsDirectoryFetch.error].
  /// 실패 시 빈 디렉터리를 정상 데이터로 반환하지 않는다(호출자가 기존 캐시 유지 결정).
  static Future<OpsDirectoryFetch> fetch() async {
    final base = ServerConfigService.instance.current.opsBaseUrl;
    const key = AppConstants.opsClientKey;
    try {
      final results = await Future.wait([
        _get('$base/api/client/contacts', key),
        _get('$base/api/client/conferences', key),
      ]);
      if (results[0].error != null || results[1].error != null) {
        final err = results[0].error ?? results[1].error ?? 'fetch-failed';
        AppLogger.instance.w('OPS directory fetch failed: $err base=$base');
        return OpsDirectoryFetch.error(err);
      }
      final cj = results[0].data;
      final rj = results[1].data;
      final contacts = <OpsContact>[];
      final rooms = <OpsRoom>[];
      if (cj != null) {
        for (final e in (cj['contacts'] as List? ?? const [])) {
          if (e is! Map) continue;
          final ext = (e['extension'] ?? '').toString();
          if (ext.isEmpty) continue;
          contacts.add(OpsContact(
            extension: ext,
            displayName: (e['display_name'] ?? '').toString(),
            sortOrder: (e['speed_dial_order'] as num?)?.toInt(),
            sipPassword: (e['sip_password'] is String &&
                    (e['sip_password'] as String).isNotEmpty)
                ? e['sip_password'] as String
                : null,
          ));
        }
      }
      if (rj != null) {
        for (final e in (rj['rooms'] as List? ?? const [])) {
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
      }
      AppLogger.instance.i(
          'OPS directory: contacts=${contacts.length} rooms=${rooms.length} base=$base');
      return OpsDirectoryFetch.ok(OpsDirectory(contacts: contacts, rooms: rooms));
    } catch (e) {
      AppLogger.instance.w('OPS directory fetch failed: $e');
      return OpsDirectoryFetch.error(e.toString());
    }
  }

  static Future<_OpsGetResult> _get(String url, String key) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      // DEV: self-signed 허용(보안통신 전환 검증용). 운영 배포 시 인증서 신뢰 기반으로 제한 필요.
      client.badCertificateCallback = (cert, host, port) => true;
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final cfg = ServerConfigService.instance.current;
      final useKey =
          cfg.clientKey.trim().isNotEmpty ? cfg.clientKey.trim() : key;
      final useExt = cfg.clientExtension.trim();
      if (useKey.isNotEmpty) req.headers.add('X-Client-Key', useKey);
      if (useExt.isNotEmpty && useKey.isNotEmpty) {
        req.headers.add('X-Client-Extension', useExt);
      }
      final res = await req.close().timeout(_timeout);
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        return _OpsGetResult.error('http-${res.statusCode}');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['ok'] != true) {
        return _OpsGetResult.error('api-not-ok');
      }
      final data = json['data'];
      return _OpsGetResult.ok(data is Map<String, dynamic> ? data : <String, dynamic>{});
    } catch (e) {
      AppLogger.instance.w('OPS directory get failed: $url (${e.runtimeType})');
      return _OpsGetResult.error(e.runtimeType.toString());
    } finally {
      client.close(force: true);
    }
  }
}

class OpsDirectoryFetch {
  OpsDirectoryFetch._({this.directory, this.error});
  factory OpsDirectoryFetch.ok(OpsDirectory directory) =>
      OpsDirectoryFetch._(directory: directory);
  factory OpsDirectoryFetch.error(String error) =>
      OpsDirectoryFetch._(error: error);

  final OpsDirectory? directory;
  final String? error;
  bool get ok => directory != null && error == null;
}

class _OpsGetResult {
  _OpsGetResult._({this.data, this.error});
  factory _OpsGetResult.ok(Map<String, dynamic> data) => _OpsGetResult._(data: data);
  factory _OpsGetResult.error(String error) => _OpsGetResult._(error: error);
  final Map<String, dynamic>? data;
  final String? error;
}
