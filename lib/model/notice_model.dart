// notice_model.dart
class NoticeModel {
  String? id;
  String? title;
  String? textContent;
  List<Files>? files;

  NoticeModel({this.id, this.title, this.textContent, this.files});

  NoticeModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    textContent = json['text_content'];
    if (json['files'] != null) {
      files = <Files>[];
      json['files'].forEach((v) {
        files!.add(Files.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['text_content'] = textContent;
    if (files != null) {
      data['files'] = files!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Files {
  String? fileName;
  String? filePath;

  Files({this.fileName, this.filePath});

  Files.fromJson(Map<String, dynamic> json) {
    fileName = json['file_name'];
    filePath = json['file_path'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['file_name'] = fileName;
    data['file_path'] = filePath;
    return data;
  }
}
