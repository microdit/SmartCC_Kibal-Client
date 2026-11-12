import 'package:flutter_test/flutter_test.dart';
import 'package:macos_client/src/sip/sdp_codec.dart';

const sdp = 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=rtpmap:111 opus/48000/2\r\n'
    'm=video 9 UDP/TLS/RTP/SAVPF 96 97 102 103 106\r\n'
    'a=rtpmap:96 VP8/90000\r\na=rtcp-fb:96 nack\r\n'
    'a=rtpmap:97 rtx/90000\r\na=fmtp:97 apt=96\r\n'
    'a=rtpmap:102 H264/90000\r\na=fmtp:102 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f\r\n'
    'a=rtpmap:103 rtx/90000\r\na=fmtp:103 apt=102\r\n'
    'a=rtpmap:106 H264/90000\r\na=fmtp:106 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\n'
    'a=sendrecv\r\n';

void main() {
  test('정책 판정', () {
    expect(videoPolicyFor('6100'), VideoCodecPolicy.h264Only);
    expect(videoPolicyFor('1201'), VideoCodecPolicy.h264First);
    expect(videoPolicyFor('6000'), VideoCodecPolicy.keep);
    expect(videoPolicyFor('1102'), VideoCodecPolicy.keep);
  });
  test('h264Only: VP8 제거, 42e01f 우선, rtx 유지', () {
    final out = applyVideoCodecPolicy(sdp, VideoCodecPolicy.h264Only);
    expect(out, contains('m=video 9 UDP/TLS/RTP/SAVPF 106 102 103\r\n'));
    expect(out, isNot(contains('VP8')));
    expect(out, contains('a=rtpmap:111 opus'));
    expect(out, contains('a=sendrecv'));
  });
  test('h264First: 순서만 변경', () {
    final out = applyVideoCodecPolicy(sdp, VideoCodecPolicy.h264First);
    expect(out, contains('m=video 9 UDP/TLS/RTP/SAVPF 106 102 103 96 97\r\n'));
    expect(out, contains('VP8'));
  });
  test('keep: 원본', () {
    expect(applyVideoCodecPolicy(sdp, VideoCodecPolicy.keep), sdp);
  });
}
