class FolderModelv2 {
  int? id;
  String? name;
  String? icon;
  int? fileCount;

  FolderModelv2({this.id, this.name, this.icon, this.fileCount});

  FolderModelv2.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    icon = json['icon'];
    fileCount = json['file_count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['icon'] = this.icon;
    data['file_count'] = this.fileCount;
    return data;
  }
}
