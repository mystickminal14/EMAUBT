import 'dart:io';

import 'package:ema_app/model/notice_model.dart';
import 'package:ema_app/screens/notice/notice_theme.dart';
import 'package:ema_app/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Auth headers helper ──────────────────────────────────────────────────────
Future<Map<String, String>> getAuthHeaders() async {
  final sp = await SharedPreferences.getInstance();
  final session = sp.getString('session');
  final csrf = sp.getString('csrf');

  final headers = <String, String>{};

  if (session != null && session.isNotEmpty) {
    headers['Cookie'] = 'EMA_SESSION=$session';
  }

  if (csrf != null && csrf.isNotEmpty) {
    headers['X-CSRF-Token'] = csrf;
  }

  return headers;
}

class NoticeDetailScreen extends StatelessWidget {
  final NoticeModel notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final attachments = notice.attachments ?? [];
    final images = attachments.where((a) => a.isImage).toList();
    final others = attachments.where((a) => !a.isImage).toList();

    return Scaffold(
      backgroundColor: NoticeTheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              tabletMaxWidth: 700,
              desktopMaxWidth: 860,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meta ──────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 13, color: NoticeTheme.textSub),
                      const SizedBox(width: 5),
                      Text(_formatDate(notice.createdAt),
                          style: NoticeTheme.dateLabel),
                      if (notice.createdByName != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.person_outline_rounded,
                            size: 13, color: NoticeTheme.textSub),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            notice.createdByName!,
                            style: NoticeTheme.dateLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (notice.priority != null) ...[
                        const Spacer(),
                        _PriorityBadge(priority: notice.priority!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Content ───────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: NoticeTheme.cardDecoration,
                    padding: const EdgeInsets.all(20),
                    child: notice.content?.isNotEmpty == true
                        ? Text(
                      notice.content!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: NoticeTheme.textMain,
                        height: 1.7,
                      ),
                    )
                        : const Text(
                      'No content provided.',
                      style: TextStyle(
                        fontSize: 15,
                        color: NoticeTheme.textSub,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                      ),
                    ),
                  ),

                  // ── Images ────────────────────────────────────────────
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionHeading('Images'),
                    const SizedBox(height: 12),
                    _ImageGallery(images: images),
                  ],

                  // ── Other attachments ─────────────────────────────────
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionHeading('Attachments'),
                    const SizedBox(height: 12),
                    ...others.map((a) => _AttachmentTile(attachment: a)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: NoticeTheme.accent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
        const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 16),
        title: Text(
          notice.title ?? 'Notice',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F6AF5), Color(0xFF7B5EA7)],
            ),
          ),
          child: const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.campaign_rounded,
                  size: 80, color: Colors.white12),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return 'Unknown date';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        '',
        'January', 'February', 'March', 'April',
        'May',     'June',     'July',   'August',
        'September','October', 'November','December',
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─── Priority badge ───────────────────────────────────────────────────────────
class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        priority[0].toUpperCase() + priority.substring(1),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── Section heading ──────────────────────────────────────────────────────────
class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: NoticeTheme.textMain,
      ),
    );
  }
}

// ─── Image gallery ────────────────────────────────────────────────────────────
class _ImageGallery extends StatelessWidget {
  final List<NoticeAttachment> images;
  const _ImageGallery({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return _ImageThumb(attachment: images.first, index: 0, all: images);
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns(mobile: 2, tablet: 3, desktop: 4),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) =>
          _ImageThumb(attachment: images[i], index: i, all: images),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final NoticeAttachment attachment;
  final int index;
  final List<NoticeAttachment> all;
  const _ImageThumb(
      {required this.attachment, required this.index, required this.all});

  @override
  Widget build(BuildContext context) {
    final url = attachment.fileUrl;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _FullScreenImageViewer(images: all, initialIndex: index),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url != null
            ? Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
            color: NoticeTheme.chip,
            child: const Center(
              child: CircularProgressIndicator(
                  color: NoticeTheme.accent, strokeWidth: 2),
            ),
          ),
          errorBuilder: (_, __, ___) => _brokenImage(),
        )
            : _brokenImage(),
      ),
    );
  }

  Widget _brokenImage() => Container(
    decoration: BoxDecoration(
      color: NoticeTheme.chip,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Icon(Icons.broken_image_rounded,
          color: NoticeTheme.textSub, size: 32),
    ),
  );
}

// ─── Full-screen image viewer ─────────────────────────────────────────────────
class _FullScreenImageViewer extends StatefulWidget {
  final List<NoticeAttachment> images;
  final int initialIndex;
  const _FullScreenImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            tooltip: 'Open in browser',
            onPressed: () =>
                _openExternal(widget.images[_current].fileUrl),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final url = widget.images[i].fileUrl;
          if (url == null) {
            return const Center(
              child: Icon(Icons.broken_image_rounded,
                  color: Colors.white38, size: 60),
            );
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: 60),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.white30,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _openExternal(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Non-image attachment tile ────────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final NoticeAttachment attachment;
  const _AttachmentTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NoticeTheme.divider),
          ),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _fileIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: NoticeTheme.textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: const TextStyle(
                          fontSize: 11, color: NoticeTheme.textSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded,
                  size: 16, color: NoticeTheme.accent),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (attachment.isPdf) {
      parts.add('PDF');
    } else if (attachment.isVideo) {
      parts.add('Video');
    } else if (attachment.isAudio) {
      parts.add('Audio');
    } else if (attachment.fileType != null) {
      parts.add(attachment.fileType!.toUpperCase());
    }
    if (attachment.displaySize.isNotEmpty) parts.add(attachment.displaySize);
    parts.add('Tap to open');
    return parts.join(' · ');
  }

  Widget _fileIcon() {
    final IconData icon;
    final Color color;
    if (attachment.isPdf) {
      icon  = Icons.picture_as_pdf_rounded;
      color = Colors.red;
    } else if (attachment.isVideo) {
      icon  = Icons.videocam_rounded;
      color = Colors.purple;
    } else if (attachment.isAudio) {
      icon  = Icons.audiotrack_rounded;
      color = Colors.orange;
    } else if (attachment.fileType?.toLowerCase() == 'doc' ||
        attachment.fileType?.toLowerCase() == 'docx') {
      icon  = Icons.description_rounded;
      color = Colors.blue;
    } else if (attachment.fileType?.toLowerCase() == 'xls' ||
        attachment.fileType?.toLowerCase() == 'xlsx') {
      icon  = Icons.table_chart_rounded;
      color = Colors.green;
    } else if (attachment.fileType?.toLowerCase() == 'txt') {
      icon  = Icons.article_rounded;
      color = Colors.blueGrey;
    } else {
      icon  = Icons.insert_drive_file_rounded;
      color = NoticeTheme.accent;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  // ── All file types: download to temp dir then open natively ───────────────
  Future<void> _open(BuildContext context) async {
    final url = attachment.downloadUrl ?? attachment.fileUrl;

    if (url == null) {
      _showSnack(context, 'File URL not available');
      return;
    }

    debugPrint('[File Download] URL: $url');

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final snackController = messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('Opening file…'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final authHeaders = await getAuthHeaders();
      debugPrint('[File Download] Headers: $authHeaders');

      final response =
      await http.get(Uri.parse(url), headers: authHeaders);
      snackController.close();

      if (response.statusCode != 200) {
        _showSnack(context, 'Download failed (${response.statusCode})');
        return;
      }

      final dir = await getTemporaryDirectory();

      // Use displayName as-is so the correct extension is preserved
      // (.pdf, .docx, .xlsx, .txt, etc.)
      final file = File('${dir.path}/${attachment.displayName}');
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('[File Download] Saved to: ${file.path}');

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done && context.mounted) {
        // Fallback: if no native app can handle it, open in browser
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnack(context, 'Could not open file: ${result.message}');
        }
      }
    } catch (e) {
      snackController.close();
      if (context.mounted) {
        _showSnack(context, 'Error opening file: $e');
      }
    }
  }

  void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}