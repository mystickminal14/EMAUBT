class AllAdminModel {
  bool? success;
  List<Admins>? admins;

  AllAdminModel({this.success, this.admins});

  AllAdminModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['admins'] != null) {
      admins = <Admins>[];
      json['admins'].forEach((v) {
        admins!.add(new Admins.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.admins != null) {
      data['admins'] = this.admins!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Admins {
  String? fullName;
  String? email;

  Admins({this.fullName, this.email});

  Admins.fromJson(Map<String, dynamic> json) {
    fullName = json['full_name'];
    email = json['email'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['full_name'] = this.fullName;
    data['email'] = this.email;
    return data;
  }
}
