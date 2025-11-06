import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  String? _currentStreamId;
  String? _userId;
  String? _userType;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String serverUrl) {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });
  }

  void joinStream(String streamId, String userId, String userType) {
    _currentStreamId = streamId;
    _userId = userId;
    _userType = userType;

    _socket?.emit('join-stream', {
      'streamId': streamId,
      'userId': userId,
      'userType': userType,
    });
  }

  void leaveStream() {
    if (_currentStreamId != null && _userId != null && _userType != null) {
      _socket?.emit('leave-stream', {
        'streamId': _currentStreamId,
        'userId': _userId,
        'userType': _userType,
      });
    }
    _currentStreamId = null;
    _userId = null;
    _userType = null;
  }

  void sendOffer(String streamId, Map<String, dynamic> offer, String targetId) {
    _socket?.emit('offer', {
      'streamId': streamId,
      'offer': offer,
      'targetId': targetId,
    });
  }

  void sendAnswer(String streamId, Map<String, dynamic> answer, String targetId) {
    _socket?.emit('answer', {
      'streamId': streamId,
      'answer': answer,
      'targetId': targetId,
    });
  }

  void sendIceCandidate(
      String streamId, Map<String, dynamic> candidate, String targetId) {
    _socket?.emit('ice-candidate', {
      'streamId': streamId,
      'candidate': candidate,
      'targetId': targetId,
    });
  }

  void sendChatMessage(
      String streamId, String message, String userId, String username) {
    _socket?.emit('chat-message', {
      'streamId': streamId,
      'message': message,
      'userId': userId,
      'username': username,
    });
  }

  void onJoinedStream(Function(Map<String, dynamic>) callback) {
    _socket?.on('joined-stream', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onOffer(Function(Map<String, dynamic>) callback) {
    _socket?.on('offer', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onAnswer(Function(Map<String, dynamic>) callback) {
    _socket?.on('answer', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onIceCandidate(Function(Map<String, dynamic>) callback) {
    _socket?.on('ice-candidate', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onViewerJoined(Function(Map<String, dynamic>) callback) {
    _socket?.on('viewer-joined', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onStreamEnded(Function() callback) {
    _socket?.on('stream-ended', (_) {
      callback();
    });
  }

  void onWaitingForViewers(Function() callback) {
    _socket?.on('waiting-for-viewers', (_) {
      callback();
    });
  }

  void onChatMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('chat-message', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void removeAllListeners() {
    _socket?.clearListeners();
  }

  void disconnect() {
    leaveStream();
    _socket?.disconnect();
    _socket = null;
  }
}

