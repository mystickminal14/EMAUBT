class FilesModel {
  String? status;
  String? message;
  List<FileData> data;

  FilesModel({this.status, this.message, this.data = const []});

  factory FilesModel.fromJson(Map<String, dynamic> json) {
    return FilesModel(
      status: json['status'] as String?,
      message: json['message'] as String?,
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
          .map((x) => FileData.fromJson(x as Map<String, dynamic>))
          .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data.map((x) => x.toJson()).toList(),
  };
}

class FileData {
  dynamic id; // Supports int or String for optimistic UI
  String? folderId;
  String? name;
  String? filePath;
  String? iconPath;

  FileData({this.id, this.folderId, this.name, this.filePath, this.iconPath});

  factory FileData.fromJson(Map<String, dynamic> json) {
    return FileData(
      id: json['id'],
      folderId: json['folder_id']?.toString(),
      name: json['name'] as String?,
      filePath: json['file_path'] as String?,
      iconPath: json['icon_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'folder_id': folderId,
    'name': name,
    'file_path': filePath,
    'icon_path': iconPath,
  };
}