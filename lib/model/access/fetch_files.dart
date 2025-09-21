class fetchallFilesModel {
  String? status;
  String? message;
  List<FilesData>? data;

  fetchallFilesModel({this.status, this.message, this.data});

  fetchallFilesModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    if (json['data'] != null) {
      data = <FilesData>[];
      json['data'].forEach((v) {
        data!.add(new FilesData.fromJson(v));
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

class FilesData {
  int? id;
  int? folderId;
  String? name;
  String? filePath;
  String? iconPath;
  bool? isActivated;

  FilesData({this.id, this.folderId, this.name, this.filePath, this.iconPath,this.isActivated});

  FilesData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    folderId = json['folder_id'];
    name = json['name'];
    filePath = json['file_path'];
    iconPath = json['icon_path'];
    isActivated = json['is_activated'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['folder_id'] = this.folderId;
    data['name'] = this.name;
    data['file_path'] = this.filePath;
    data['icon_path'] = this.iconPath;
    data['is_activated'] = this.isActivated;

    return data;
  }
}
