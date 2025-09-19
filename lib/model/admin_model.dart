class AdminModel {
  bool? success;
  List<Admins>? admins;

  AdminModel({this.success, this.admins});

  AdminModel.fromJson(Map<String, dynamic> json) {
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
  String? id;
  String? userId;
  String? fullName;
  String? email;
  String? assignedAt;

  Admins({this.id, this.userId, this.fullName, this.email, this.assignedAt});

  Admins.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    fullName = json['full_name'];
    email = json['email'];
    assignedAt = json['assigned_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['user_id'] = this.userId;
    data['full_name'] = this.fullName;
    data['email'] = this.email;
    data['assigned_at'] = this.assignedAt;
    return data;
  }
}
