class UserModelData {
  bool? success;
  List<Users>? users;

  UserModelData({this.success, this.users});

  UserModelData.fromJson(Map<String, dynamic> json) {
    success = json['success'] as bool?;
    if (json['users'] != null) {
      users = <Users>[];
      (json['users'] as List<dynamic>).forEach((v) {
        users!.add(Users.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    if (users != null) {
      data['users'] = users!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Users {
  String? id; // Changed to String for API consistency
  String? fullName;
  String? email;
  String? phone;
  String? image;

  Users({this.id, this.fullName, this.email, this.phone, this.image});

  Users.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? ''; // Ensure id is a string
    fullName = json['full_name']?.toString() ?? 'No Name';
    email = json['email']?.toString() ?? 'No Email';
    phone = json['phone']?.toString();
    image = json['image']?.toString();
  }

  Map<String, String> toJson() {
    return {
      'user_id': id ?? '',
      'full_name': fullName ?? 'No Name',
      'email': email ?? 'No Email',
      if (phone != null) 'phone': phone!,
      if (image != null) 'image': image!,
    };
  }
}