class FileModel {
  int? id;
  String? name;
  String? fileType;
  int? fileSize;
  int? folderId;
  String? filePath;
  String? uploadedAt;
  int? accessCount;

  FileModel({
    this.id,
    this.name,
    this.fileType,
    this.fileSize,
    this.folderId,
    this.filePath,
    this.uploadedAt,
    this.accessCount,
  });

  FileModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    fileType = json['file_type'];
    fileSize = json['file_size'];
    folderId = json['folder_id'];
    filePath = json['file_path'];
    uploadedAt = json['uploaded_at'];
    accessCount = json['access_count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['name'] = name;
    data['file_type'] = fileType;
    data['file_size'] = fileSize;
    data['folder_id'] = folderId;
    data['file_path'] = filePath;
    data['uploaded_at'] = uploadedAt;
    data['access_count'] = accessCount;
    return data;
  }

  /// Returns a human-readable file size string
  String get formattedSize {
    if (fileSize == null) return 'Unknown size';
    if (fileSize! < 1024) return '${fileSize} B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Returns the file extension
  String get extension {
    if (name == null || !name!.contains('.')) return '';
    return name!.split('.').last.toLowerCase();
  }

  bool get isImage {
    return ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(extension);
  }

  bool get isPdf => extension == 'pdf';

  bool get isAudio {
    return ['mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a'].contains(extension);
  }

  bool get isVideo {
    return ['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(extension);
  }

  bool get isDocument {
    return ['doc', 'docx', 'txt', 'rtf', 'odt'].contains(extension);
  }
}