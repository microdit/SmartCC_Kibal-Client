import 'package:flutter/material.dart';

import '../../utils/app_logger.dart';
import '../../utils/remote_log_filter.dart';
import '../../utils/remote_log_forwarder.dart';
import '../../utils/remote_log_settings.dart';

/// 로그 전송 설정 다이얼로그
///
/// 모드(끄기/오류만/INFO/이벤트/INFO+이벤트/DEBUG/전체/사용자 지정),
/// 사용자 지정 레벨·도메인·통계 포함, 서버 주소/키, 연결 테스트, 전송 상태.
Future<void> showRemoteLogSettingsDialog(BuildContext context) {
  AppLogger.instance.ui('SETTINGS', 'remoteLogSettingsOpened');
  return showDialog<void>(
    context: context,
    builder: (_) => const _RemoteLogSettingsDialog(),
  );
}

Future<void> showLogSendDialog(BuildContext context) {
  AppLogger.instance.ui('SETTINGS', 'logSendOpened');
  return showDialog<void>(
    context: context,
    builder: (_) => const _LogSendDialog(),
  );
}

class _LogSendDialog extends StatefulWidget {
  const _LogSendDialog();

  @override
  State<_LogSendDialog> createState() => _LogSendDialogState();
}

class _LogSendDialogState extends State<_LogSendDialog> {
  final _forwarder = RemoteLogForwarder.instance;
  bool _sending = false;
  String? _message;

  Future<void> _sendNow() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    await _forwarder.sendNow();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _message = '현재 로그 즉시 전송을 요청했습니다.';
    });
  }

  void _toggleAuto(bool value) {
    _forwarder.setAutoSend(value);
    setState(() {
      _message = value
          ? '자동전송 시작: 지금 1회 전송 후 5분마다 전송합니다.'
          : '자동전송을 중지했습니다.';
    });
  }

  String _fmt(DateTime? t) {
    if (t == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_upload_outlined),
          SizedBox(width: 8),
          Text('로그보내기'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<RemoteLogStatus>(
              valueListenable: _forwarder.status,
              builder: (_, s, __) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('자동보내기 (5분 주기)'),
                subtitle: Text(
                  '즉시 1회 전송 후 5분마다 분할 전송 · 마지막 ${_fmt(s.lastSentAt)}',
                  style: const TextStyle(fontSize: 11),
                ),
                value: _forwarder.settings.autoSend,
                onChanged: _toggleAuto,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendNow,
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                label: const Text('즉시보내기 (1회)'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '자동보내기와 즉시보내기는 동시에 사용할 수 있습니다. '
              '자동 대기 중에도 즉시보내기를 누르면 현재 로그가 바로 전송됩니다.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!,
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => showRemoteLogSettingsDialog(context),
          child: const Text('전송 설정'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _RemoteLogSettingsDialog extends StatefulWidget {
  const _RemoteLogSettingsDialog();

  @override
  State<_RemoteLogSettingsDialog> createState() =>
      _RemoteLogSettingsDialogState();
}

class _RemoteLogSettingsDialogState extends State<_RemoteLogSettingsDialog> {
  final _forwarder = RemoteLogForwarder.instance;
  late RemoteLogMode _mode;
  late Set<String> _levels;
  late Set<String> _domains;
  late bool _includeStats;
  late TextEditingController _url;
  late TextEditingController _key;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final s = _forwarder.settings;
    _mode = s.mode;
    _levels = {...s.levels};
    _domains = {...s.domains};
    _includeStats = s.includeStats;
    _url = TextEditingController(text: s.url);
    _key = TextEditingController(text: s.key);
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  RemoteLogSettings _build() {
    final current = _forwarder.settings;
    final url = _url.text.trim();
    return RemoteLogSettings(
      mode: _mode,
      url: url,
      key: _key.text.trim(),
      levels: _levels,
      domains: _domains,
      includeStats: _includeStats,
      urlOverridden: current.urlOverridden || url != current.url,
      autoSend: current.autoSend,
    );
  }

  void _save() {
    _forwarder.applySettings(_build());
    Navigator.of(context).pop();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final previous = _forwarder.settings;
    _forwarder.settings = _build(); // 저장 없이 임시 적용
    final ok = await _forwarder.testConnection();
    _forwarder.settings = previous;
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok
          ? '연결 성공'
          : '연결 실패 (${_forwarder.status.value.lastError ?? '알 수 없음'})';
    });
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final heavy = _mode == RemoteLogMode.all ||
        _mode == RemoteLogMode.debug ||
        (_mode == RemoteLogMode.custom && _includeStats);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined),
          const SizedBox(width: 8),
          const Text('로그 전송 설정'),
          const Spacer(),
          if (heavy)
            const Chip(
              label: Text('대량 전송 중', style: TextStyle(fontSize: 11)),
              backgroundColor: Color(0x33FFA000),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RemoteLogMode>(
                initialValue: _mode,
                decoration: const InputDecoration(
                  labelText: '전송 모드',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in RemoteLogMode.values)
                    DropdownMenuItem(value: m, child: Text(_modeLabel(m))),
                ],
                onChanged: (m) => setState(() => _mode = m ?? _mode),
              ),
              const SizedBox(height: 6),
              const Text(
                '로컬 app.log에는 항상 전체가 기록됩니다. 모드 변경은 이후 로그부터 적용됩니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (_mode == RemoteLogMode.debug)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('SIP stats(5초 통계) 포함'),
                  value: _includeStats,
                  onChanged: (v) => setState(() => _includeStats = v),
                ),
              if (_mode == RemoteLogMode.custom) ...[
                const SizedBox(height: 12),
                const Text('레벨', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final lv in kLogLevels)
                      FilterChip(
                        label: Text(lv),
                        selected: _levels.contains(lv),
                        onSelected: (v) => setState(() {
                          v ? _levels.add(lv) : _levels.remove(lv);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('이벤트 도메인(msg)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final d in kEventDomains)
                      FilterChip(
                        label: Text(d),
                        selected: _domains.contains(d),
                        onSelected: (v) => setState(() {
                          v ? _domains.add(d) : _domains.remove(d);
                        }),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('SIP stats(5초 통계) 포함'),
                  value: _includeStats,
                  onChanged: (v) => setState(() => _includeStats = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: '서버 주소',
                  hintText: 'http://192.168.11.5:8091/api/client-logs',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '클라이언트 키 (X-Client-Key)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<RemoteLogStatus>(
                valueListenable: _forwarder.status,
                builder: (_, s, __) => Text(
                  '내선 ${_forwarder.extension} · 세션 ${_forwarder.session}\n'
                  '마지막 전송 ${_fmtTime(s.lastSentAt)} · 전송 ${s.sentLines}줄 · '
                  '미전송 ${(s.pendingBytes / 1024).toStringAsFixed(1)}KB'
                  '${s.connected == false ? '\n최근 오류: ${s.lastError}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 6),
                Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _testResult == '연결 성공' ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.wifi_tethering, size: 18),
          label: const Text('연결 테스트'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }

  String _modeLabel(RemoteLogMode m) {
    switch (m) {
      case RemoteLogMode.off:
        return '끄기 — 전송 안 함';
      case RemoteLogMode.errors:
        return '오류만 — WARN/ERROR';
      case RemoteLogMode.info:
        return 'INFO — INFO/WARN/ERROR';
      case RemoteLogMode.events:
        return '이벤트(msg) — EVENT/WARN/ERROR';
      case RemoteLogMode.infoEvents:
        return 'INFO + 이벤트 (기본)';
      case RemoteLogMode.debug:
        return 'DEBUG — DEBUG 포함';
      case RemoteLogMode.all:
        return '전체 — 모든 로그';
      case RemoteLogMode.custom:
        return '사용자 지정';
    }
  }
}
