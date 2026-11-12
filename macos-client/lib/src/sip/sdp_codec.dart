/// SDP 영상 코덱 정책 (ADR-007)
///
/// - 6000~6099: 기존(VP8 우선) — 변경 없음
/// - 6100~6199: H.264만 (follow_talker, A10 SIP 호환)
/// - SIP 단말(12xx) 1:1: H.264 우선
enum VideoCodecPolicy { keep, h264First, h264Only }

VideoCodecPolicy videoPolicyFor(String? target) {
  final t = (target ?? '').trim();
  if (RegExp(r'^61\d\d$').hasMatch(t)) return VideoCodecPolicy.h264Only;
  if (RegExp(r'^12\d\d$').hasMatch(t)) return VideoCodecPolicy.h264First;
  return VideoCodecPolicy.keep;
}

/// m=video 섹션 payload 재정렬/필터. H.264가 없으면 원본 유지.
/// h264Only: H.264(+해당 rtx) 이외 PT 제거. 우선 profile-level-id 42e01f.
String applyVideoCodecPolicy(String sdp, VideoCodecPolicy policy) {
  if (policy == VideoCodecPolicy.keep) return sdp;
  final eol = sdp.contains('\r\n') ? '\r\n' : '\n';
  final lines = sdp.split(eol);
  final out = <String>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (!line.startsWith('m=video')) {
      out.add(line);
      i++;
      continue;
    }
    // 섹션 수집
    final section = <String>[line];
    i++;
    while (i < lines.length && !lines[i].startsWith('m=')) {
      section.add(lines[i]);
      i++;
    }
    out.addAll(_rewriteVideo(section, policy));
  }
  return out.join(eol);
}

List<String> _rewriteVideo(List<String> section, VideoCodecPolicy policy) {
  final mParts = section.first.split(' ');
  if (mParts.length < 4) return section;
  final pts = mParts.sublist(3);
  final codec = <String, String>{}; // pt -> name
  final fmtp = <String, String>{};
  for (final l in section) {
    final r = RegExp(r'^a=rtpmap:(\d+) ([^/]+)/').firstMatch(l);
    if (r != null) codec[r.group(1)!] = r.group(2)!.toUpperCase();
    final f = RegExp(r'^a=fmtp:(\d+) (.*)$').firstMatch(l);
    if (f != null) fmtp[f.group(1)!] = f.group(2)!;
  }
  final h264 = pts.where((p) => codec[p] == 'H264').toList();
  if (h264.isEmpty) return section;
  // 42e01f(constrained baseline) 우선, packetization-mode=1 우선
  int score(String p) {
    final f = (fmtp[p] ?? '').toLowerCase();
    return (f.contains('profile-level-id=42e01f') ? 2 : 0) +
        (f.contains('packetization-mode=1') ? 1 : 0);
  }
  h264.sort((a, b) => score(b).compareTo(score(a)));
  // rtx 연결(apt=)
  final rtxFor = <String, String>{};
  fmtp.forEach((p, f) {
    final m = RegExp(r'apt=(\d+)').firstMatch(f);
    if (m != null && codec[p] == 'RTX') rtxFor[m.group(1)!] = p;
  });
  final keepH264 = <String>[];
  for (final p in h264) {
    keepH264.add(p);
    final r = rtxFor[p];
    if (r != null) keepH264.add(r);
  }
  final List<String> newPts;
  if (policy == VideoCodecPolicy.h264Only) {
    final extras = pts.where((p) => codec[p] == 'RED' || codec[p] == 'ULPFEC').toList();
    newPts = [...keepH264, ...extras];
  } else {
    newPts = [...keepH264, ...pts.where((p) => !keepH264.contains(p))];
  }
  final keep = newPts.toSet();
  final result = <String>['${mParts.sublist(0, 3).join(' ')} ${newPts.join(' ')}'];
  for (final l in section.skip(1)) {
    final m = RegExp(r'^a=(rtpmap|fmtp|rtcp-fb):(\d+)').firstMatch(l);
    if (m != null && !keep.contains(m.group(2))) continue;
    result.add(l);
  }
  return result;
}
