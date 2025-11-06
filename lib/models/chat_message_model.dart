class ChatMessageModel {
  final String message;
  final String userId;
  final String username;
  final String timestamp;

  ChatMessageModel({
    required this.message,
    required this.userId,
    required this.username,
    required this.timestamp,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      message: json['message'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'userId': userId,
      'username': username,
      'timestamp': timestamp,
    };
  }
}

