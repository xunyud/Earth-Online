import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';

/// 语音记忆播放控件行
class VoicePlaybackRow extends StatefulWidget {
  final String? audioUrl;

  const VoicePlaybackRow({super.key, required this.audioUrl});

  @override
  State<VoicePlaybackRow> createState() => _VoicePlaybackRowState();
}

class _VoicePlaybackRowState extends State<VoicePlaybackRow> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _playing = false;
  bool _error = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  @override
  void initState() {
    super.initState();
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    _player = AudioPlayer();
    try {
      _loading = true;
      if (mounted) setState(() {});
      await _player!.setUrl(widget.audioUrl!);
      _duration = _player!.duration ?? Duration.zero;
      _loading = false;
      if (mounted) setState(() {});

      _stateSub = _player!.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playing = false;
            _position = Duration.zero;
            _player!.seek(Duration.zero);
          }
        });
      });

      _posSub = _player!.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _durSub = _player!.durationStream.listen((dur) {
        if (dur != null && mounted) setState(() => _duration = dur);
      });
    } catch (_) {
      _loading = false;
      _error = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_player == null || _error) return;
    if (_playing) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.audioUrl != null && widget.audioUrl!.isNotEmpty;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A5B8A58)),
      ),
      child: Row(
        children: [
          const Text('🎙️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (!hasUrl || _error || _loading) ? null : _togglePlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _playing
                    ? const Color(0xFFE53935).withAlpha(20)
                    : const Color(0xFF5A7654).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                      color: _error
                          ? AppColors.textHint
                          : (_playing
                              ? const Color(0xFFE53935)
                              : const Color(0xFF5A7654)),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _error
                ? Text(
                    context.tr('memory.voice.audio_unavailable'),
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFFE53935),
                      fontSize: 11,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: const Color(0x225B8A58),
                          color: const Color(0xFF5A7654),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(_position),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _fmt(_duration),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
