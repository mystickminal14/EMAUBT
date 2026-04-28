class QuizSetModel {
  int? id;
  int? folderId;
  String? name;
  String? description;
  String? iconPath;
  int? questionCount;
  int? durationMinutes;
  int? passingScore;
  bool? isPublished;
  String? createdAt;

  QuizSetModel({
    this.id,
    this.folderId,
    this.name,
    this.description,
    this.iconPath,
    this.questionCount,
    this.durationMinutes,
    this.passingScore,
    this.isPublished,
    this.createdAt,
  });

  QuizSetModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    folderId = json['folder_id'];
    name = json['name'];
    description = json['description'];
    iconPath = json['icon_path'];
    questionCount = json['question_count'];
    durationMinutes = json['duration_minutes'];
    passingScore = json['passing_score'];
    isPublished = json['is_published'];
    createdAt = json['created_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['folder_id'] = folderId;
    data['name'] = name;
    data['description'] = description;
    data['icon_path'] = iconPath;
    data['question_count'] = questionCount;
    data['duration_minutes'] = durationMinutes;
    data['passing_score'] = passingScore;
    data['is_published'] = isPublished;
    data['created_at'] = createdAt;
    return data;
  }
}