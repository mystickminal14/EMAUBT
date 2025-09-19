class UserModel {
  String? fullName;
  String? email;
  String? phone;
  String? password;
  String? image;
  bool? success;
  String? role;
  String? name;

  UserModel(
      {this.fullName,
        this.email,
        this.phone,
        this.password,
        this.image,
        this.success,
        this.role,
        this.name});

  UserModel.fromJson(Map<String, dynamic> json) {
    fullName = json['full_name'];
    email = json['email'];
    phone = json['phone'];
    password = json['password'];
    image = json['image'];
    success = json['success'];
    role = json['role'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['full_name'] = this.fullName;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['password'] = this.password;
    data['image'] = this.image;
    data['success'] = this.success;
    data['role'] = this.role;
    data['name'] = this.name;
    return data;
  }
}
