import 'package:flutter/material.dart';

import '../../utils/live_quality_service.dart';

class LiveQualityOverlay extends StatelessWidget {
  const LiveQualityOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LiveQualitySnapshot?>(
      valueListenable: LiveQualityService.instance.snapshot,
      builder: (_, s, __) {
        if (s == null) {
          return const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xCC000000),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('진단 데이터 수집 중…',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xD9000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('전송 속도 진단',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Chip(
                        label: Text(s.verdict,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                        backgroundColor: s.verdict == '양호'
                            ? Colors.green
                            : Colors.orangeAccent,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _section('영상'),
                  _row('해상도/코덱', '${s.videoResolution} · ${s.videoCodec}'),
                  _row('fps', '${s.videoFps.toStringAsFixed(0)} / 평균 '
                      '${s.avgVideoFps.toStringAsFixed(0)}'),
                  _row('bitrate', '${s.videoBitrateKbps.toStringAsFixed(0)} / 평균 '
                      '${s.avgVideoBitrateKbps.toStringAsFixed(0)} kbps'),
                  _row('손실/freeze/PLI/NACK',
                      '${s.videoPacketsLost}/${s.freezeCount}/${s.pliCount}/${s.nackCount}'),
                  const SizedBox(height: 6),
                  _section('음성'),
                  _row('코덱', s.audioCodec),
                  _row('bitrate', '${s.audioBitrateKbps.toStringAsFixed(0)} / 평균 '
                      '${s.avgAudioBitrateKbps.toStringAsFixed(0)} kbps'),
                  _row('jitter / 손실',
                      '${s.jitterMs.toStringAsFixed(1)}ms / ${s.audioPacketsLost}'),
                  const SizedBox(height: 6),
                  _section('네트워크'),
                  _row('RTT', '${s.rttMs.toStringAsFixed(0)} / 평균 '
                      '${s.avgRttMs.toStringAsFixed(0)} ms'),
                  _row('가용 송신량',
                      '${s.availableOutgoingKbps.toStringAsFixed(0)} kbps'),
                  _row('ICE', s.candidateState.isEmpty ? '-' : s.candidateState),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _section(String title) => Text(
        title,
        style: const TextStyle(
            color: Colors.tealAccent,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10))),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
      );
}
