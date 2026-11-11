import 'package:flutter_test/flutter_test.dart';
import 'package:macos_client/src/utils/remote_log_filter.dart';

const info = '[2026-11-11T15:00:00.000] INFO [usr=1102@x host=h ip=i] SIP state -> registered';
const warn = '[2026-11-11T15:00:00.000] WARN [usr=1102@x host=h ip=i] 경고';
const error = '[2026-11-11T15:00:00.000] ERROR [usr=1102@x host=h ip=i] 실패';
const evtSip = '[2026-11-11T15:00:00.000] EVENT SIP op=callEstablished target=6000';
const evtUi = '[2026-11-11T15:00:00.000] EVENT UI CALL action=hangupPressed';
const debug = '[2026-11-11T15:00:00.000] DEBUG [usr=1102@x host=h ip=i] remote session handled';
const stats = '[2026-11-11T15:00:00.000] DEBUG [usr=1102@x host=h ip=i] SIP stats inbound audioBytes=1 videoBytes=2';
const stack = '  at main.dart:10';

List<bool> run(RemoteLogFilter f) =>
    [info, warn, error, evtSip, evtUi, debug, stats, stack].map(f.shouldSend).toList();

void main() {
  test('끄기', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.off)),
        [false, false, false, false, false, false, false, false]);
  });
  test('오류만', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.errors)),
        [false, true, true, false, false, false, false, false]);
  });
  test('INFO', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.info)),
        [true, true, true, false, false, false, false, true]);
  });
  test('이벤트(msg)', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.events)),
        [false, true, true, true, true, false, false, true]);
  });
  test('INFO + 이벤트', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.infoEvents)),
        [true, true, true, true, true, false, false, true]);
  });
  test('DEBUG (stats 제외/포함)', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.debug)),
        [true, true, true, true, true, true, false, true]);
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.debug, includeStats: true)),
        [true, true, true, true, true, true, true, true]);
  });
  test('전체', () {
    expect(run(const RemoteLogFilter(mode: RemoteLogMode.all)).every((v) => v), isTrue);
  });
  test('사용자 지정: ERROR + EVENT(SIP만)', () {
    expect(
        run(const RemoteLogFilter(
            mode: RemoteLogMode.custom, levels: {'ERROR', 'EVENT'}, domains: {'SIP'})),
        [false, false, true, true, false, false, false, true]);
  });
}
