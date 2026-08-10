import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:chewie/chewie.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/viewer/cross_platform_pdf_view.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// What kind of renderer a file needs.
enum _ViewerKind { image, pdf, text, video, audio, unsupported }

_ViewerKind _kindFor(String nameOrPath) {
  final ext = nameOrPath.split('?').first.split('.').last.toLowerCase();
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
    return _ViewerKind.image;
  }
  if (ext == 'pdf') return _ViewerKind.pdf;
  if (['txt', 'csv', 'json', 'md', 'log', 'xml', 'yaml', 'yml', 'ini', 'html']
      .contains(ext)) {
    return _ViewerKind.text;
  }
  if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
    return _ViewerKind.video;
  }
  if (['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(ext)) {
    return _ViewerKind.audio;
  }
  return _ViewerKind.unsupported;
}

/// Full-screen, in-app viewer for a file served from `/api/res/…`.
///
/// The bytes are fetched with the session headers and rendered inside the app.
/// PDF / video / audio renderers need a real path, so those bytes are parked in
/// the app's *temporary* cache — nothing is ever saved to the user's Downloads
/// folder and no external app is launched.
class InAppFileViewerPage extends StatefulWidget {
  final String url;
  final String fileName;

  const InAppFileViewerPage({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<InAppFileViewerPage> createState() => _InAppFileViewerPageState();
}

class _InAppFileViewerPageState extends State<InAppFileViewerPage> {
  late final _ViewerKind _kind =
      _kindFor(widget.fileName.contains('.') ? widget.fileName : widget.url);

  bool _loading = true;
  String? _error;

  Uint8List? _bytes; // images
  String? _text; // text files
  String? _cachePath; // pdf / video / audio

  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  AudioPlayer? _audio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  // ── Fetch + prepare ────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await getAuthHeaders();
      final response =
          await http.get(Uri.parse(widget.url), headers: headers);

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = response.statusCode == 401 || response.statusCode == 403
              ? 'You do not have access to this file.'
              : 'Could not open this file (${response.statusCode}).';
        });
        return;
      }

      switch (_kind) {
        case _ViewerKind.image:
          _bytes = response.bodyBytes;
          break;
        case _ViewerKind.text:
          _text = utf8.decode(response.bodyBytes, allowMalformed: true);
          break;
        case _ViewerKind.pdf:
        case _ViewerKind.video:
        case _ViewerKind.audio:
        case _ViewerKind.unsupported:
          // Office documents, archives and anything else we cannot render get
          // cached too, so the user can hand them to the OS's default app.
          _cachePath = await _writeToCache(response.bodyBytes);
          if (_kind == _ViewerKind.video) await _initVideo(_cachePath!);
          if (_kind == _ViewerKind.audio) await _initAudio(_cachePath!);
          break;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open this file: $e';
      });
    }
  }

  /// Writes the payload into the app cache and returns its path.
  Future<String> _writeToCache(Uint8List bytes) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/ema_preview');
    if (!await dir.exists()) await dir.create(recursive: true);

    final safeName =
        widget.fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _initVideo(String path) async {
    final ctrl = VideoPlayerController.file(File(path));
    await ctrl.initialize();
    _videoCtrl = ctrl;
    _chewieCtrl = ChewieController(
      videoPlayerController: ctrl,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: FolderTheme.accent,
        handleColor: FolderTheme.accent,
      ),
    );
  }

  Future<void> _initAudio(String path) async {
    final player = AudioPlayer();
    await player.setSourceDeviceFile(path);
    _audio = player;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dark = _kind == _ViewerKind.image || _kind == _ViewerKind.video;

    return Scaffold(
      backgroundColor: dark ? Colors.black : FolderTheme.surface,
      appBar: AppBar(
        backgroundColor: dark ? Colors.black : FolderTheme.card,
        foregroundColor: dark ? Colors.white : FolderTheme.textMain,
        elevation: 0.5,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: FolderTheme.accent, strokeWidth: 2.5),
      );
    }

    if (_error != null) return _errorView(_error!);

    switch (_kind) {
      case _ViewerKind.image:
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Center(child: Image.memory(_bytes!)),
        );

      case _ViewerKind.text:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _text!,
            style: const TextStyle(
                fontSize: 14, height: 1.6, color: FolderTheme.textMain),
          ),
        );

      case _ViewerKind.pdf:
        return CrossPlatformPdfView(
          filePath: _cachePath!,
          onError: (e) {
            if (!mounted) return;
            setState(() => _error = 'Error loading PDF: $e');
          },
        );

      case _ViewerKind.video:
        return Center(
          child: _chewieCtrl == null
              ? _errorView('Could not play this video.')
              : AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio,
            child: Chewie(controller: _chewieCtrl!),
          ),
        );

      case _ViewerKind.audio:
        return _AudioPanel(player: _audio!, fileName: widget.fileName);

      case _ViewerKind.unsupported:
        return _externalOpenView();
    }
  }

  /// Shown for file types no in-app renderer can handle (docx, xlsx, zip …).
  /// The bytes are already cached, so the OS's default app can take over.
  Widget _externalOpenView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_rounded,
                size: 44, color: FolderTheme.textSub),
            const SizedBox(height: 16),
            Text(widget.fileName,
                textAlign: TextAlign.center, style: FolderTheme.emptyTitle),
            const SizedBox(height: 8),
            const Text(
              'This file type cannot be previewed in the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FolderTheme.textSub),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openWithDefaultApp,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open with default app'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FolderTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWithDefaultApp() async {
    if (_cachePath == null) return;
    final result = await OpenFile.open(_cachePath!);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open this file: ${result.message}')),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off_rounded,
                size: 44, color: FolderTheme.textSub),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center, style: FolderTheme.emptyTitle),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FolderTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Audio panel ──────────────────────────────────────────────────────────────
class _AudioPanel extends StatefulWidget {
  final AudioPlayer player;
  final String fileName;

  const _AudioPanel({required this.player, required this.fileName});

  @override
  State<_AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<_AudioPanel> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    widget.player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    widget.player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    widget.player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.clamp(0, _duration.inMilliseconds);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack_rounded,
                size: 64, color: FolderTheme.accent),
            const SizedBox(height: 20),
            Text(widget.fileName,
                textAlign: TextAlign.center, style: FolderTheme.emptyTitle),
            const SizedBox(height: 24),
            Slider(
              value: value.toDouble(),
              max: max <= 0 ? 1 : max,
              activeColor: FolderTheme.accent,
              onChanged: max <= 0
                  ? null
                  : (v) =>
                  widget.player.seek(Duration(milliseconds: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(_position), style: FolderTheme.cardSubtitle),
                  Text(_fmt(_duration), style: FolderTheme.cardSubtitle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            IconButton.filled(
              iconSize: 34,
              style: IconButton.styleFrom(backgroundColor: FolderTheme.accent),
              icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: () =>
              _playing ? widget.player.pause() : widget.player.resume(),
            ),
          ],
        ),
      ),
    );
  }
}
