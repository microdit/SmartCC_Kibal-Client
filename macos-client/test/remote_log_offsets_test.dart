import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_client/src/utils/remote_log_forwarder.dart';

void main() {
  test('줄별 끝 offset은 UTF-8 바이트 기준(한글 포함)', () {
    const text = 'abc\n한글 로그\n[x] INFO z\n';
    final r = RemoteLogForwarder.splitWithEnds(text, 100);
    expect(r.map((e) => e.$1).toList(), ['abc', '한글 로그', '[x] INFO z']);
    expect(r.last.$2, 100 + utf8.encode(text).length);
    expect(r.first.$2, 104);
    expect(r[1].$2, 104 + utf8.encode('한글 로그').length + 1);
  });
}
