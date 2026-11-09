import 'package:flutter_test/flutter_test.dart';
import 'package:macos_client/src/sip/sip_config.dart';

void main() {
  group('SipConfig', () {
    test('WebRTC 설정 직렬화/역직렬화', () {
      final config = SipConfig.webrtc(
        username: '1101',
        password: 'secret',
        domain: '192.168.11.2',
        wsServer: 'ws://192.168.11.2:8088/ws',
      );

      final restored = SipConfig.fromJson(config.toJson());

      expect(restored.username, '1101');
      expect(restored.domain, '192.168.11.2');
      expect(restored.transportType, SipTransportType.ws);
      expect(restored.wsServer, 'ws://192.168.11.2:8088/ws');
    });

    test('UDP 기본 포트', () {
      final config = SipConfig.udp(
        username: '1001',
        password: 'secret',
        domain: '127.0.0.1',
      );

      expect(config.port, 5060);
      expect(config.transportType, SipTransportType.udp);
    });
  });
}
