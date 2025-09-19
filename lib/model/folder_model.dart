class FolderModel {
  String? id;
  String? name;
  String? iconPath;
  String? iconUrl;

  FolderModel({this.id, this.name, this.iconPath, this.iconUrl});

  FolderModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    iconPath = json['icon_path'];
    iconUrl = json['icon_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['icon_path'] = this.iconPath;
    data['icon_url'] = this.iconUrl;
    return data;
  }
}
