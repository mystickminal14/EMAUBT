import 'package:ema_app/model/notice_model.dart';
import 'package:flutter/material.dart';
import 'notice_theme.dart';

class NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const NoticeCard({
    super.key,
    required this.notice,
    required this.index,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasAttachments =
        notice.attachments != null && notice.attachments!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: NoticeTheme.cardDecoration,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IndexBadge(index: index),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notice.title ?? 'Untitled',
                      style: NoticeTheme.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (notice.priority != null)
                    _PriorityDot(priority: notice.priority!),
                  if (onEdit != null || onDelete != null)
                    _ContextMenu(onEdit: onEdit, onDelete: onDelete),
                ],
              ),
              const SizedBox(height: 10),
              if (notice.content?.isNotEmpty == true)
                Text(
                  notice.content!,
                  style: NoticeTheme.cardBody,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: NoticeTheme.textSub),
                  const SizedBox(width: 4),
                  Text(_formatDate(notice.createdAt),
                      style: NoticeTheme.dateLabel),
                  if (notice.createdByName != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline_rounded,
                        size: 12, color: NoticeTheme.textSub),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        notice.createdByName!,
                        style: NoticeTheme.dateLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (hasAttachments)
                    _AttachmentChip(count: notice.attachments!.length),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')} '
          '${_month(dt.month)} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _month(int m) => const [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];
}

// ─── Priority dot ─────────────────────────────────────────────────────────────
class _PriorityDot extends StatelessWidget {
  final String priority;
  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
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
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─── Index badge ──────────────────────────────────────────────────────────────
class _IndexBadge extends StatelessWidget {
  final int index;
  const _IndexBadge({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: NoticeTheme.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.campaign_rounded,
            color: NoticeTheme.accent, size: 20),
      ),
    );
  }
}

// ─── Attachment chip ──────────────────────────────────────────────────────────
class _AttachmentChip extends StatelessWidget {
  final int count;
  const _AttachmentChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NoticeTheme.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file_rounded,
              size: 12, color: NoticeTheme.accent),
          const SizedBox(width: 4),
          Text(
            '$count file${count > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 11,
                color: NoticeTheme.accent,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Context menu ─────────────────────────────────────────────────────────────
class _ContextMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _ContextMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: NoticeTheme.textSub, size: 20),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit?.call();
        if (v == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_rounded, size: 16, color: NoticeTheme.accent),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: NoticeTheme.danger),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: NoticeTheme.danger)),
            ]),
          ),
      ],
    );
  }
}