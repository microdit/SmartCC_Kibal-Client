import 'package:flutter/material.dart';

import '../../utils/app_logger.dart';
import '../../utils/client_auth_state.dart';
import '../../utils/quality_report.dart';
import 'metric_chart.dart';

Future<void> showQualityReportDialog(BuildContext context) {
  AppLogger.instance.ui('SETTINGS', 'qualityReportOpened');
  return showDialog<void>(
    context: context,
    builder: (_) => const _QualityReportDialog(),
  );
}

class _QualityReportDialog extends StatefulWidget {
  const _QualityReportDialog();

  @override
  State<_QualityReportDialog> createState() => _QualityReportDialogState();
}

class _QualityReportDialogState extends State<_QualityReportDialog> {
  QualityMetrics? _report;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = await ClientAuthStore.instance().load();
    final ext = auth.authExtension.isNotEmpty ? auth.authExtension : '1102';
    try {
      final report = await QualityReportService.fetch(extension: ext);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _verdictColor(QualityVerdict v) {
    switch (v) {
      case QualityVerdict.good:
        return Colors.green;
      case QualityVerdict.warning:
        return Colors.orange;
      case QualityVerdict.critical:
        return Colors.redAccent;
    }
  }

  String _fmt(DateTime? t) {
    if (t == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.monitor_heart_outlined),
          SizedBox(width: 8),
          Text('테스트 결과 · 품질 지표'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Text('조회 실패: $_error')
                  : _buildReport(_report!),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('새로고침'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildReport(QualityMetrics r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Chip(
              label: Text(
                r.verdictLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: _verdictColor(r.verdict),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('내선 ${r.extension} · IP ${r.ip ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '수집 구간 ${_fmt(r.firstAt)} ~ ${_fmt(r.lastAt)} · '
          'video ${r.videoSamples}건 / media ${r.mediaSamples}건',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        const Text('평균 상태', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
          children: [
            _row('평균 수신 fps', r.avgFps.toStringAsFixed(1)),
            _row('평균 videoKB/30s', r.avgVideoKB.toStringAsFixed(0)),
            _row('해상도', r.resolution ?? '-'),
            _row('ICE', r.iceState ?? '-'),
            _row('vLost 증가', '${r.vLostDelta}'),
            _row('freeze 증가', '${r.freezeDelta}'),
            _row('pli 증가', '${r.pliDelta}'),
            _row('audioLost 증가', '${r.audioLostDelta}'),
            _row('keyframe 증가', '${r.keyframeDelta}'),
            _row('decoded 증가', '${r.decodedDelta}'),
          ],
        ),
        const SizedBox(height: 12),
        const Text('추이 그래프 (추가 패키지 없이 Flutter SDK로 렌더링)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        MetricChart(
          title: '수신 fps',
          values: r.fpsSeries,
          color: Colors.teal,
          fixedMax: 60,
        ),
        MetricChart(
          title: 'vLost 증가 / 구간',
          values: r.vLostSeries,
          color: Colors.redAccent,
          bars: true,
        ),
        MetricChart(
          title: 'freeze 증가 / 구간',
          values: r.freezeSeries,
          color: Colors.orange,
          bars: true,
        ),
        MetricChart(
          title: 'pli 증가 / 구간',
          values: r.pliSeries,
          color: Colors.indigo,
          bars: true,
        ),
        const SizedBox(height: 12),
        const Text('진단 결과', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...r.findings.map((f) => Text('• $f',
            style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 8),
        const Text('조치 의견', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...r.recommendations.map((f) => Text('• $f',
            style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  TableRow _row(String label, String value) => TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      );
}
