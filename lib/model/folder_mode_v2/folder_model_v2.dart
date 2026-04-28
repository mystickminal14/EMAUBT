class FolderModelv2 {
  String? name;
  int? id;
  String? iconPath;
  int? fileCount;

  FolderModelv2({this.name, this.id, this.iconPath, this.fileCount});

  FolderModelv2.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    id = json['id'];
    iconPath = json['icon_path'];
    fileCount = json['file_count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['id'] = this.id;
    data['icon_path'] = this.iconPath;
    data['file_count'] = this.fileCount;
    return data;
  }
}
