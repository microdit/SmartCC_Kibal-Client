import 'package:flutter_test/flutter_test.dart';
import 'package:macos_client/src/utils/media_device_settings.dart';

void main() {
  test('A10/Yealink 추천 판정', () {
    expect(MediaDeviceSettings.isRecommended('Yealink A10 Camera'), isTrue);
    expect(MediaDeviceSettings.isRecommended('MeetingBar Audio'), isTrue);
    expect(MediaDeviceSettings.isRecommended('FaceTime HD Camera'), isFalse);
  });
}
