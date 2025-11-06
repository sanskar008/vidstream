import 'package:flutter/foundation.dart';
import '../models/stream_model.dart';
import '../services/stream_service.dart';
import '../services/socket_service.dart';
import '../config/api_config.dart';

class StreamProvider with ChangeNotifier {
  final StreamService _streamService = StreamService();
  final SocketService _socketService = SocketService();
  List<StreamModel> _liveStreams = [];
  StreamModel? _currentStream;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, bool> _likedStreams = {};
  Map<String, int> _streamLikesCount = {};
  bool _socketInitialized = false;

  List<StreamModel> get liveStreams => _liveStreams;
  StreamModel? get currentStream => _currentStream;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isLiked(String streamId) => _likedStreams[streamId] ?? false;
  int getLikesCount(String streamId) => _streamLikesCount[streamId] ?? 0;

  Future<void> fetchLiveStreams() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _streamService.getLiveStreams();

    _isLoading = false;

    if (result['success'] == true) {
      _liveStreams = result['streams'];
      _errorMessage = null;
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
  }

  Future<bool> createStream({
    required String title,
    String description = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _streamService.createStream(
      title: title,
      description: description,
    );

    _isLoading = false;

    if (result['success'] == true) {
      _currentStream = result['stream'];
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  Future<bool> getStreamByCode(String streamCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _streamService.getStreamByCode(streamCode);

    _isLoading = false;

    if (result['success'] == true) {
      _currentStream = result['stream'];
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinStream(String streamId) async {
    final result = await _streamService.joinStream(streamId);
    if (result['success'] == true) {
      await fetchLiveStreams();
      await getLikeStatus(streamId);
      return true;
    }
    _errorMessage = result['message'];
    notifyListeners();
    return false;
  }

  Future<void> getLikeStatus(String streamId) async {
    final result = await _streamService.getLikeStatus(streamId);
    if (result['success'] == true) {
      _likedStreams[streamId] = result['liked'];
      _streamLikesCount[streamId] = result['likesCount'];
      notifyListeners();
    }
  }

  Future<bool> toggleLike(String streamId) async {
    final result = await _streamService.likeStream(streamId);
    if (result['success'] == true) {
      _likedStreams[streamId] = result['liked'];
      _streamLikesCount[streamId] = result['likesCount'];
      
      if (_currentStream?.id == streamId) {
        _currentStream = StreamModel(
          id: _currentStream!.id,
          streamCode: _currentStream!.streamCode,
          title: _currentStream!.title,
          description: _currentStream!.description,
          creator: _currentStream!.creator,
          isLive: _currentStream!.isLive,
          viewers: _currentStream!.viewers,
          likes: result['likesCount'],
          createdAt: _currentStream!.createdAt,
          endedAt: _currentStream!.endedAt,
        );
      }
      
      final index = _liveStreams.indexWhere((s) => s.id == streamId);
      if (index != -1) {
        _liveStreams[index] = StreamModel(
          id: _liveStreams[index].id,
          streamCode: _liveStreams[index].streamCode,
          title: _liveStreams[index].title,
          description: _liveStreams[index].description,
          creator: _liveStreams[index].creator,
          isLive: _liveStreams[index].isLive,
          viewers: _liveStreams[index].viewers,
          likes: result['likesCount'],
          createdAt: _liveStreams[index].createdAt,
          endedAt: _liveStreams[index].endedAt,
        );
      }
      
      notifyListeners();
      return true;
    }
    _errorMessage = result['message'];
    notifyListeners();
    return false;
  }

  void setCurrentStream(StreamModel? stream, {String? userId, String? userType}) {
    _currentStream = stream;
    if (stream != null) {
      if (!_socketInitialized) {
        _initializeSocketListeners();
      }
      // Join the stream room to receive updates if user info is provided
      if (userId != null && userType != null) {
        _socketService.joinStream(stream.id, userId, userType);
      }
    }
    notifyListeners();
  }

  void _initializeSocketListeners() {
    if (_socketInitialized) return;
    
    _socketService.connect(ApiConfig.socketUrl);
    _socketService.onLikeUpdated((data) {
      final streamId = data['streamId'] as String;
      final likesCount = data['likesCount'] as int;
      
      _streamLikesCount[streamId] = likesCount;
      
      if (_currentStream?.id == streamId) {
        _currentStream = StreamModel(
          id: _currentStream!.id,
          streamCode: _currentStream!.streamCode,
          title: _currentStream!.title,
          description: _currentStream!.description,
          creator: _currentStream!.creator,
          isLive: _currentStream!.isLive,
          viewers: _currentStream!.viewers,
          likes: likesCount,
          createdAt: _currentStream!.createdAt,
          endedAt: _currentStream!.endedAt,
        );
      }
      
      final index = _liveStreams.indexWhere((s) => s.id == streamId);
      if (index != -1) {
        _liveStreams[index] = StreamModel(
          id: _liveStreams[index].id,
          streamCode: _liveStreams[index].streamCode,
          title: _liveStreams[index].title,
          description: _liveStreams[index].description,
          creator: _liveStreams[index].creator,
          isLive: _liveStreams[index].isLive,
          viewers: _liveStreams[index].viewers,
          likes: likesCount,
          createdAt: _liveStreams[index].createdAt,
          endedAt: _liveStreams[index].endedAt,
        );
      }
      
      notifyListeners();
    });
    
    _socketInitialized = true;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

