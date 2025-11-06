class StreamModel {
  final String id;
  final String streamCode;
  final String title;
  final String description;
  final CreatorModel creator;
  final bool isLive;
  final int viewers;
  final DateTime createdAt;
  final DateTime? endedAt;

  StreamModel({
    required this.id,
    required this.streamCode,
    required this.title,
    required this.description,
    required this.creator,
    required this.isLive,
    this.viewers = 0,
    required this.createdAt,
    this.endedAt,
  });

  factory StreamModel.fromJson(Map<String, dynamic> json) {
    return StreamModel(
      id: json['id'] ?? json['_id'] ?? '',
      streamCode: json['streamCode'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      creator: CreatorModel.fromJson(json['creator'] ?? {}),
      isLive: json['isLive'] ?? false,
      viewers: json['viewers'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'streamCode': streamCode,
      'title': title,
      'description': description,
      'creator': creator.toJson(),
      'isLive': isLive,
      'viewers': viewers,
      'createdAt': createdAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }
}

class CreatorModel {
  final String id;
  final String username;

  CreatorModel({
    required this.id,
    required this.username,
  });

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    return CreatorModel(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}

