import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'constants.dart';
import 'server_config.dart';

class OpsContact {
  OpsContact({required this.extension, required this.displayName, this.sortOrder});
  final String extension;
  final String displayName;
  final int? sortOrder;

  String get label =>
      displayName.isNotEmpty && displayName != extension ? '$extension $displayName' : extension;
}

class OpsRoom {
  OpsRoom({required this.room, required this.name, required this.mode, this.sortOrder});
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

  static Future<OpsDirectory> fetch() async {
    final base = ServerConfigService.instance.current.opsBaseUrl;
    final key = AppConstants.opsClientKey;
    try {
      final results = await Future.wait([
        _get('$base/api/client/contacts', key),
        _get('$base/api/client/conferences', key),
      ]);
      final contacts = <OpsContact>[];
      final rooms = <OpsRoom>[];
      final cj = results[0];
      if (cj != null) {
        for (final e in (cj['contacts'] as List? ?? const [])) {
          if (e is! Map) continue;
          final ext = (e['extension'] ?? '').toString();
          if (ext.isEmpty) continue;
          contacts.add(OpsContact(
            extension: ext,
            displayName: (e['display_name'] ?? '').toString(),
            sortOrder: (e['speed_dial_order'] as num?)?.toInt(),
          ));
        }
      }
      final rj = results[1];
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
      AppLogger.instance.i('OPS directory: contacts=${contacts.length} rooms=${rooms.length} base=$base');
      return OpsDirectory(contacts: contacts, rooms: rooms);
    } catch (e) {
      AppLogger.instance.w('OPS directory fetch failed: $e');
      return const OpsDirectory();
    }
  }

  static Future<Map<String, dynamic>?> _get(String url, String key) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      if (key.isNotEmpty) req.headers.add('X-Client-Key', key);
      final res = await req.close().timeout(_timeout);
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['ok'] != true) return null;
      final data = json['data'];
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
