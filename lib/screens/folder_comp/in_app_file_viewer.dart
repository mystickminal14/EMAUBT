import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:chewie/chewie.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

enum _ViewerKind { pdf, image, video, audio, text, unsupported }

/// Shows a file from the server inside the app.
///
/// The bytes are fetched into the app cache only so the platform viewers can
/// read them; nothing is written to Downloads and no share/save action is
/// offered — content is view-only. The cache copy is removed on dispose.
class InAppFileViewerPage extends StatefulWidget {
  final String fileName;
  final String filePath;

  const InAppFileViewerPage({
    super.key,
    required this.fileName,
    required this.filePath,
  });

  @override
  State<InAppFileViewerPage> createState() => _InAppFileViewerPageState();
}

class _InAppFileViewerPageState extends State<InAppFileViewerPage> {
  bool _loading = true;
  String? _error;
  File? _file;
  String? _textContent;
  late final _ViewerKind _kind;

  @override
  void initState() {
    super.initState();
    _kind = _kindFor(widget.fileName, widget.filePath);
    _load();
  }

  static _ViewerKind _kindFor(String name, String path) {
    final source = name.contains('.') ? name : path;
    final ext = source.split('.').last.toLowerCase().split('?').first;

    const image = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
    const video = {'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'm4v'};
    const audio = {'mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a'};
    const text = {'txt', 'csv', 'json', 'xml', 'html', 'md', 'rtf'};

    if (ext == 'pdf') return _ViewerKind.pdf;
    if (image.contains(ext)) return _ViewerKind.image;
    if (video.contains(ext)) return _ViewerKind.video;
    if (audio.contains(ext)) return _ViewerKind.audio;
    if (text.contains(ext)) return _ViewerKind.text;
    return _ViewerKind.unsupported;
  }

  Future<void> _load() async {
    if (_kind == _ViewerKind.unsupported) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = BaseUrl.resUrl(widget.filePath);
      if (url.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'This file has no path on the server.';
        });
        return;
      }

      final headers = await getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = response.statusCode == 404
              ? 'File not found on the server (404).'
              : 'Could not open this file (${response.statusCode}).';
        });
        return;
      }

      final dir = await getTemporaryDirectory();
      final safeName = widget.fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
      final cacheFile = File(
          '${dir.path}/ema_view_${DateTime.now().millisecondsSinceEpoch}_$safeName');
      await cacheFile.writeAsBytes(response.bodyBytes);

      String? text;
      if (_kind == _ViewerKind.text) {
        text = String.fromCharCodes(response.bodyBytes);
      }

      if (!mounted) return;
      setState(() {
        _file = cacheFile;
        _textContent = text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error opening file: $e';
      });
    }
  }

  @override
  void dispose() {
    final f = _file;
    if (f != null) {
      f.delete().catchError((_) => f);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMedia = _kind == _ViewerKind.video || _kind == _ViewerKind.image;

    return Scaffold(
      backgroundColor: isMedia ? Colors.black : FolderTheme.surface,
      appBar: AppBar(
        backgroundColor: isMedia ? Colors.black : FolderTheme.card,
        foregroundColor: isMedia ? Colors.white : FolderTheme.textMain,
        elevation: 0,
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

    if (_error != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open file',
        message: _error!,
        onRetry: _load,
      );
    }

    if (_kind == _ViewerKind.unsupported) {
      return const _Message(
        icon: Icons.visibility_off_rounded,
        title: 'Preview not available',
        message: 'This file type cannot be viewed inside the app.',
      );
    }

    final file = _file;
    if (file == null) {
      return const _Message(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open file',
        message: 'The file could not be loaded.',
      );
    }

    switch (_kind) {
      case _ViewerKind.pdf:
        return _PdfBody(file: file);
      case _ViewerKind.image:
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(child: Image.file(file)),
        );
      case _ViewerKind.video:
        return _VideoBody(file: file);
      case _ViewerKind.audio:
        return _AudioBody(file: file, fileName: widget.fileName);
      case _ViewerKind.text:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _textContent ?? '',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        );
      case _ViewerKind.unsupported:
        return const SizedBox.shrink();
    }
  }
}

// ─── PDF ────────────────────────────────────────────────────────────────────
class _PdfBody extends StatelessWidget {
  final File file;
  const _PdfBody({required this.file});

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return const _Message(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Preview not available',
        message: 'PDF preview is only supported on Android and iOS.',
      );
    }
    return PDFView(
      filePath: file.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
    );
  }
}

// ─── Video ──────────────────────────────────────────────────────────────────
class _VideoBody extends StatefulWidget {
  final File file;
  const _VideoBody({required this.file});

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.file(widget.file);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _chewie = ChewieController(
          videoPlayerController: ctrl,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: FolderTheme.accent,
            handleColor: FolderTheme.accent,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not play this video: $e');
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _Message(
        icon: Icons.videocam_off_rounded,
        title: 'Cannot play video',
        message: _error!,
        dark: true,
      );
    }
    final chewie = _chewie;
    if (chewie == null) {
      return const Center(
        child: CircularProgressIndicator(
            color: FolderTheme.accent, strokeWidth: 2.5),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Chewie(controller: chewie),
      ),
    );
  }
}

// ─── Audio ──────────────────────────────────────────────────────────────────
class _AudioBody extends StatefulWidget {
  final File file;
  final String fileName;
  const _AudioBody({required this.file, required this.fileName});

  @override
  State<_AudioBody> createState() => _AudioBodyState();
}

class _AudioBodyState extends State<_AudioBody> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.play(DeviceFileSource(widget.file.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.clamp(0, _duration.inMilliseconds);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: FolderTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note_rounded,
                size: 44, color: FolderTheme.accent),
          ),
          const SizedBox(height: 20),
          Text(
            widget.fileName,
            style: FolderTheme.cardTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Slider(
            value: max <= 0 ? 0 : value.toDouble(),
            max: max <= 0 ? 1 : max,
            activeColor: FolderTheme.accent,
            onChanged: max <= 0
                ? null
                : (v) => _player.seek(Duration(milliseconds: v.round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_position), style: FolderTheme.emptySubtitle),
                Text(_fmt(_duration), style: FolderTheme.emptySubtitle),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IconButton(
            iconSize: 56,
            color: FolderTheme.accent,
            onPressed: () =>
                _playing ? _player.pause() : _player.resume(),
            icon: Icon(_playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded),
          ),
        ],
      ),
    );
  }
}

// ─── Shared message state ───────────────────────────────────────────────────
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool dark;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : FolderTheme.textMain;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: FolderTheme.accent),
            const SizedBox(height: 16),
            Text(title,
                style: FolderTheme.emptyTitle.copyWith(color: textColor)),
            const SizedBox(height: 8),
            Text(
              message,
              style: FolderTheme.emptySubtitle,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FolderTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
