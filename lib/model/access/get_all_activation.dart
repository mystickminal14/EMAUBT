class GetAllActivation {
  String? status;
  List<ActivateData>? data;
  int? count;

  GetAllActivation({this.status, this.data, this.count});

  GetAllActivation.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['data'] != null) {
      data = <ActivateData>[];
      json['data'].forEach((v) {
        data!.add(new ActivateData.fromJson(v));
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

class ActivateData {
  String? itemType;
  int? itemId;
  bool? isActivated;
  String? itemName;

  ActivateData({this.itemType, this.itemId, this.isActivated, this.itemName});

  ActivateData.fromJson(Map<String, dynamic> json) {
    itemType = json['item_type'];
    itemId = json['item_id'];
    isActivated = json['is_activated'];
    itemName = json['item_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['item_type'] = this.itemType;
    data['item_id'] = this.itemId;
    data['is_activated'] = this.isActivated;
    data['item_name'] = this.itemName;
    return data;
  }
}
