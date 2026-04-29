class UserModel {
  final int? id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? image;
  final String? csrf;
  final String? role;
  final bool? success;

  const UserModel({
    this.id,
    this.fullName,
    this.email,
    this.phone,
    this.image,
    this.role,
    this.success, this.csrf,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Support both flat (legacy) and nested data.user structure
    final Map<String, dynamic> user =
    (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'])
        : json;

    return UserModel(
      id: user['id'] is int
          ? user['id']
          : int.tryParse(user['id']?.toString() ?? ''),
      fullName: user['full_name'] ?? user['name'],
      email: user['email'],
      csrf: user['csrf_token'],
      phone: user['phone'],
      image: user['image'],
      role: user['role'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'image': image,
    'role': role,
    'csrf_token':csrf
  };
}