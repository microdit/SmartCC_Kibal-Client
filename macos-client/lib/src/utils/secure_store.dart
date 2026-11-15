import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'app_logger.dart';

/// 멀티플랫폼 공통 보안 저장 추상화.
/// - macOS Keychain 단독 의존 회피(플랫폼별 전용 API 직접 사용 안 함)
/// - 앱 샌드박스 Application Support 하위 파일에 XOR+난수 마스크 기반 경량 난독화 저장
///   (OS 보안 저장소 수준의 보호는 아니나, 평문 노출/로그 혼입을 줄이고 구현을 플랫폼 공통으로 유지)
abstract class SecureStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll(Iterable<String> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }
}

class FileSecureStore extends SecureStore {
  FileSecureStore._(this._dirPath);
  static FileSecureStore? _instance;

  final String _dirPath;
  static const _salt = 'kibal-client-sec-v1';

  static FileSecureStore instance() {
    if (_instance != null) return _instance!;
    final base = AppLogger.logDirectory; // .../Application Support/.../logs
    final dir = Directory('${Directory(base).parent.path}/secure');
    _instance = FileSecureStore._(dir.path);
    return _instance!;
  }

  File _fileFor(String key) {
    final safe = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return File('$_dirPath/$safe.bin');
  }

  Uint8List _keystream(int len, Uint8List nonce) {
    // 간단한 스트림(난독화): seed = salt + nonce 기반 의사난수
    final seedBytes = utf8.encode(_salt).followedBy(nonce).toList();
    var h = 2166136261;
    for (final b in seedBytes) {
      h ^= b;
      h = (h * 16777619) & 0xffffffff;
    }
    final rnd = Random(h);
    final out = Uint8List(len);
    for (var i = 0; i < len; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }

  Uint8List _xor(Uint8List data, Uint8List ks) {
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ ks[i];
    }
    return out;
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final dir = Directory(_dirPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final plain = Uint8List.fromList(utf8.encode(value));
      final nonce = Uint8List(16);
      final rnd = Random.secure();
      for (var i = 0; i < nonce.length; i++) {
        nonce[i] = rnd.nextInt(256);
      }
      final ks = _keystream(plain.length, nonce);
      final cipher = _xor(plain, ks);
      final payload = <String, dynamic>{
        'v': 1,
        'n': base64Encode(nonce),
        'c': base64Encode(cipher),
      };
      await _fileFor(key).writeAsString(jsonEncode(payload), flush: true);
    } catch (e) {
      AppLogger.instance.w('SecureStore write 실패(key 마스킹): $e');
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      final f = _fileFor(key);
      if (!f.existsSync()) return null;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (json['v'] != 1) return null;
      final nonce = Uint8List.fromList(base64Decode(json['n'] as String));
      final cipher = Uint8List.fromList(base64Decode(json['c'] as String));
      final ks = _keystream(cipher.length, nonce);
      final plain = _xor(cipher, ks);
      return utf8.decode(plain);
    } catch (e) {
      AppLogger.instance.w('SecureStore read 실패(key 마스킹): $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final f = _fileFor(key);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      AppLogger.instance.w('SecureStore delete 실패: $e');
    }
  }
}
