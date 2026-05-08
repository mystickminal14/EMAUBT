import 'package:ema_app/constants/base_url.dart';

class FileModel {
  int?    id;
  int?    folderId;
  String? name;
  String? accessType;
  String? status;
  /// Relative path from server e.g. "uploads/icons/icon_xxx.jpg"
  String? iconPath;

  /// Relative path from server e.g. "uploads/files/file_xxx.pdf"
  String? filePath;
  String? folderName;
  String? folderIconPath;
  String? createdAt;

  FileModel({
    this.id,
    this.folderId,
    this.name,
    this.accessType,
    this.status,
    this.iconPath,
    this.filePath,
    this.folderName,
    this.folderIconPath,
    this.createdAt,
  });

  // ── fromJson — maps actual API keys ──────────────────────────────────────
  FileModel.fromJson(Map<String, dynamic> json) {
    id             = json['id'];
    folderId       = json['folder_id'];
    name           = json['name'];
    accessType     = json['access_type'];
    status = json['status'];
    iconPath       = json['icon_path'];   // "uploads/icons/icon_xxx.jpg"
    filePath       = json['file_path'];   // "uploads/files/file_xxx.pdf"
    folderName     = json['folder_name'];
    folderIconPath = json['folder_icon_path'];
    createdAt      = json['created_at'];
  }

  Map<String, dynamic> toJson() => {
    'id':               id,
    'folder_id':        folderId,
    'name':             name,
    'access_type':      accessType,
    'status':status,
    'icon_path':        iconPath,
    'file_path':        filePath,
    'folder_name':      folderName,
    'folder_icon_path': folderIconPath,
    'created_at':       createdAt,
  };

  // ── Full URLs ─────────────────────────────────────────────────────────────

  /// Full URL to display the icon image
  /// e.g. http://10.10.100.144:8000/uploads/icons/icon_xxx.jpg
  String? get iconUrl {
    if (iconPath == null || iconPath!.isEmpty) return null;
    return '${BaseUrl.baseUrl}/res/$iconPath';
  }

  /// e.g. http://10.10.100.144:8000/api/files/{id}/download
  String get downloadUrl =>
      '${BaseUrl.baseUrl}/files/$id/download';

  /// Full URL to stream/view the raw file
  /// e.g. http://10.10.100.144:8000/uploads/files/file_xxx.pdf
  String? get fileViewUrl {
    if (filePath == null || filePath!.isEmpty) return null;
    final base = BaseUrl.baseUrl.replaceAll('/api', '');
    return '$base/$filePath';
  }

  // ── File type helpers (derived from filePath extension) ───────────────────
  String get extension {
    final path = filePath ?? name ?? '';
    return path.split('.').last.toLowerCase();
  }

  bool get isImage    => ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  bool get isPdf      => extension == 'pdf';
  bool get isAudio    => ['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(extension);
  bool get isVideo    => ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
  bool get isDocument => ['doc', 'docx', 'txt', 'rtf', 'odt',
    'xls', 'xlsx', 'ppt', 'pptx'].contains(extension);

  String get fileTypeName {
    if (isPdf)      return 'PDF';
    if (isImage)    return 'Image';
    if (isAudio)    return 'Audio';
    if (isVideo)    return 'Video';
    if (isDocument) return 'Document';
    return extension.toUpperCase();
  }
}