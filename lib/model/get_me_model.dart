class GetMeModel {
  final bool? success;
  final int? id;
  final String? fullName;
  final String? image;
  final String? email;
  final String? phone;
  final String? role;

  GetMeModel({
    this.success,
    this.id,
    this.fullName,
    this.image,
    this.email,
    this.phone,
    this.role,
  });

  factory GetMeModel.fromJson(Map<String, dynamic> json) => GetMeModel(
    success: true,               // data existing means success
    id: json['id'],
    fullName: json['full_name'], // ← API uses full_name not fullName
    image: json['image'],
    email: json['email'],
    phone: json['phone'],
    role: json['role'],
  );
}