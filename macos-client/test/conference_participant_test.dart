import 'package:flutter_test/flutter_test.dart';
import 'package:macos_client/src/utils/conference_participants.dart';

void main() {
  test('라벨: 표시 이름 (내선), 없으면 내선', () {
    final a = ConferenceParticipant.fromJson({
      'channel': 'PJSIP/1102-1', 'extension': '1102', 'display_name': '이재명', 'has_video': true,
    })!;
    final b = ConferenceParticipant.fromJson({
      'channel': 'PJSIP/1101-2', 'extension': '1101', 'display_name': '1101',
    })!;
    expect(a.label, '이재명 (1102)');
    expect(b.label, '1101');
    expect(b.hasVideo, isFalse);
  });
}
