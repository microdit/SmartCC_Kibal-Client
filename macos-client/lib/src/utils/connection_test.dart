import 'dart:convert';
import 'dart:io';

import 'server_config.dart';

class ConnectionTestResult {
  ConnectionTestResult({
    required this.label,
    required this.ok,
    required this.detail,
  });

  final String label;
  final bool ok;
  final String detail;
}

class ConnectionTestService {
  ConnectionTestService._();

  static final ConnectionTestService instance = ConnectionTestService._();

  static const _timeout = Duration(seconds: 4);

  Future<List<ConnectionTestResult>> test({
    required ConnectionProfile profile,
    required ServerConfig config,
    required String clientKey,
    required String extension,
  }) async {
    final results = <ConnectionTestResult>[];
    final opsUrls = <String>{
      config.opsBaseUrl,
      ...profile.candidates,
    }.toList();

    for (final url in opsUrls) {
      final result = await _testOps(url, clientKey, extension);
      results.add(result);
      if (result.ok) break;
    }

    results.add(await _testWs(config.wsServer));
    results.add(await _testLog(config.clientLogUrl));
    return results;
  }

  Future<ConnectionTestResult> _testOps(
    String base,
    String key,
    String extension,
  ) async {
    final url = '$base/api/client/config';
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      client.badCertificateCallback = (cert, host, port) => true;
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      if (key.isNotEmpty) req.headers.add('X-Client-Key', key);
      if (extension.isNotEmpty) req.headers.add('X-Client-Extension', extension);
      final res = await req.close().timeout(_timeout);
      await res.transform(utf8.decoder).join();
      return ConnectionTestResult(
        label: 'OPS 설정 ($base)',
        ok: res.statusCode == 200,
        detail: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      return ConnectionTestResult(
        label: 'OPS 설정 ($base)',
        ok: false,
        detail: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<ConnectionTestResult> _testWs(String wsServer) async {
    try {
      final uri = Uri.parse(wsServer);
      final host = uri.host;
      final port = uri.port;
      if (host.isEmpty || port == 0) {
        return ConnectionTestResult(
          label: 'WS 포트',
          ok: false,
          detail: 'URL 형식 오류: $wsServer',
        );
      }
      final socket = await Socket.connect(host, port, timeout: _timeout);
      socket.destroy();
      return ConnectionTestResult(
        label: 'WS 포트 ($host:$port)',
        ok: true,
        detail: 'TCP 연결 성공',
      );
    } catch (e) {
      return ConnectionTestResult(
        label: 'WS 포트',
        ok: false,
        detail: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<ConnectionTestResult> _testLog(String logUrl) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      client.badCertificateCallback = (cert, host, port) => true;
      final req = await client.getUrl(Uri.parse(logUrl)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      await res.transform(utf8.decoder).join();
      return ConnectionTestResult(
        label: '로그 서버',
        ok: res.statusCode < 500,
        detail: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      return ConnectionTestResult(
        label: '로그 서버',
        ok: false,
        detail: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      client.close(force: true);
    }
  }
}
