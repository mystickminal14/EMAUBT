class UserPermission {
  final int id;
  final int userId;
  final int itemId;
  final String itemType;
  final int accessTimes;
  final String grantedAt;

  const UserPermission({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemType,
    required this.accessTimes,
    required this.grantedAt,
  });

  factory UserPermission.fromJson(Map<String, dynamic> json) => UserPermission(
    id: (json['id'] as num).toInt(),
    userId: (json['user_id'] as num).toInt(),
    itemId: (json['item_id'] as num).toInt(),
    itemType: json['item_type'] as String,
    accessTimes: (json['access_times'] as num).toInt(),
    grantedAt: json['granted_at'] as String,
  );
}
