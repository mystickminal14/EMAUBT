class QuizSetModel {
  String? status;
  String? message;
  List<QuizSetData> data;

  QuizSetModel({this.status, this.message, this.data = const []});

  factory QuizSetModel.fromJson(Map<String, dynamic> json) {
    return QuizSetModel(
      status: json['status'] as String?,
      message: json['message'] as String?,
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
          .map((v) => QuizSetData.fromJson(v as Map<String, dynamic>))
          .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data.map((v) => v.toJson()).toList(),
  };
}

class QuizSetData {
  int? id;
  int? folderId;
  String? name;
  String? iconPath;

  QuizSetData({this.id, this.folderId, this.name, this.iconPath});

  factory QuizSetData.fromJson(Map<String, dynamic> json) {
    return QuizSetData(
      id: json['id'] as int?,
      folderId: json['folder_id'] as int?,
      name: json['name'] as String?,
      iconPath: json['icon_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'folder_id': folderId,
    'name': name,
    'icon_path': iconPath,
  };
}