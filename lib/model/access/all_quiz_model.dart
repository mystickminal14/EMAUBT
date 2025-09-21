class AllQuizModel {
  String? status;
  String? message;
  List<QuizData>? data;

  AllQuizModel({this.status, this.message, this.data});

  AllQuizModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    if (json['data'] != null) {
      data = <QuizData>[];
      json['data'].forEach((v) {
        data!.add(new QuizData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class QuizData {
  int? id;
  int? folderId;
  String? name;
  String? iconPath;
  bool? isActivated;

  QuizData({this.id, this.folderId, this.name, this.iconPath,this.isActivated});

  QuizData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    folderId = json['folder_id'];
    name = json['name'];
    iconPath = json['icon_path'];
    isActivated = json['is_activated'];

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['folder_id'] = this.folderId;
    data['name'] = this.name;
    data['icon_path'] = this.iconPath;
    data['is_activated'] = this.isActivated;
    return data;
  }
}
