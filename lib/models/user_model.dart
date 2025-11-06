class UserModel {
  final String id;
  final String username;
  final String email;
  final String userType;
  final int followersCount;
  final int followingCount;
  final int? liveStreams;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    this.followersCount = 0,
    this.followingCount = 0,
    this.liveStreams,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      userType: json['userType'] ?? '',
      followersCount: json['followersCount'] ?? json['followers']?.length ?? 0,
      followingCount: json['followingCount'] ?? json['following']?.length ?? 0,
      liveStreams: json['liveStreams'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'userType': userType,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'liveStreams': liveStreams,
    };
  }
}

