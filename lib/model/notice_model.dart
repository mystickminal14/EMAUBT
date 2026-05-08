
import 'package:ema_app/constants/base_url.dart';

class NoticeModel {
  final String? id;
  final String? title;
  final String? content;
  final List<NoticeAttachment>? attachments;
  final String? createdAt;
  final String? updatedAt;
  final String? noticeType;
  final String? priority;
  final String? createdByName;

  const NoticeModel({
    this.id,
    this.title,
    this.content,
    this.attachments,
    this.createdAt,
    this.updatedAt,
    this.noticeType,
    this.priority,
    this.createdByName,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      content: json['content']?.toString(),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => NoticeAttachment.fromJson(
          Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      noticeType: json['notice_type']?.toString(),
      priority: json['priority']?.toString(),
      createdByName: json['created_by_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'attachments': attachments?.map((a) => a.toJson()).toList(),
    'created_at': createdAt,
    'updated_at': updatedAt,
    'notice_type': noticeType,
    'priority': priority,
    'created_by_name': createdByName,
  };
}

class NoticeAttachment {
  final String? id;
  final String? fileName;
  final String? filePath;
  final String? mimeType;
  final String? fileType;
  final int? fileSize;

  const NoticeAttachment({
    this.id,
    this.fileName,
    this.filePath,
    this.mimeType,
    this.fileType,
    this.fileSize,
  });

  factory NoticeAttachment.fromJson(Map<String, dynamic> json) {
    return NoticeAttachment(
      id: json['id']?.toString(),
      fileName: json['file_name']?.toString() ?? json['name']?.toString(),
      filePath: json['file_path']?.toString(),
      mimeType: json['mime_type']?.toString(),
      fileType: json['file_type']?.toString(),
      fileSize: json['file_size'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'file_name': fileName,
    'file_path': filePath,
    'mime_type': mimeType,
    'file_type': fileType,
    'file_size': fileSize,
  };

  // ── URL builders ─────────────────────────────────────────────────────────

  String? get fileUrl {
    if (filePath == null) return null;
    final base = BaseUrl.imageUrl.endsWith('/')
        ? BaseUrl.imageUrl
        : '${BaseUrl.imageUrl}/';
    return '$base$filePath';
  }

  String? get downloadUrl {
    if (id == null) return null;
    return '${BaseUrl.baseUrl}/files/$id/download';
  }

  // ── Type helpers ──────────────────────────────────────────────────────────

  bool get isImage {
    if (mimeType?.startsWith('image/') == true) return true;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(_ext);
  }

  bool get isPdf {
    if (mimeType == 'application/pdf') return true;
    return _ext == 'pdf';
  }

  bool get isVideo {
    if (mimeType?.startsWith('video/') == true) return true;
    return ['mp4', 'mov', 'avi', 'mkv'].contains(_ext);
  }

  bool get isAudio {
    if (mimeType?.startsWith('audio/') == true) return true;
    return ['mp3', 'wav', 'aac', 'm4a'].contains(_ext);
  }

  String? get _ext {
    if (fileType != null) return fileType!.toLowerCase();
    final name = fileName ?? filePath?.split('/').last ?? '';
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return null;
  }

  String get displayName =>
      fileName ?? filePath?.split('/').last ?? 'Attachment';

  String get displaySize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}