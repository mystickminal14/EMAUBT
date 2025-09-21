class GetAllPermissionModel {
  String? status;
  List<PermssionData>? data;
  int? count;

  GetAllPermissionModel({this.status, this.data, this.count});

  GetAllPermissionModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['data'] != null) {
      data = <PermssionData>[];
      json['data'].forEach((v) {
        data!.add(new PermssionData.fromJson(v));
      });
    }
    count = json['count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['count'] = this.count;
    return data;
  }
}

class PermssionData {
  String? identifier;
  bool? isAdmin;
  int? itemId;
  String? itemType;
  int? accessTimes;
  int? timesAccessed;
  String? itemName;

  PermssionData(
      {this.identifier,
        this.isAdmin,
        this.itemId,
        this.itemType,
        this.accessTimes,
        this.timesAccessed,
        this.itemName});

  PermssionData.fromJson(Map<String, dynamic> json) {
    identifier = json['identifier'];
    isAdmin = json['is_admin'];
    itemId = json['item_id'];
    itemType = json['item_type'];
    accessTimes = json['access_times'];
    timesAccessed = json['times_accessed'];
    itemName = json['item_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['identifier'] = this.identifier;
    data['is_admin'] = this.isAdmin;
    data['item_id'] = this.itemId;
    data['item_type'] = this.itemType;
    data['access_times'] = this.accessTimes;
    data['times_accessed'] = this.timesAccessed;
    data['item_name'] = this.itemName;
    return data;
  }
}
