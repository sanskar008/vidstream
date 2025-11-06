import 'package:flutter/foundation.dart';
import '../models/stream_model.dart';
import '../services/stream_service.dart';

class StreamProvider with ChangeNotifier {
  final StreamService _streamService = StreamService();
  List<StreamModel> _liveStreams = [];
  StreamModel? _currentStream;
  bool _isLoading = false;
  String? _errorMessage;

  List<StreamModel> get liveStreams => _liveStreams;
  StreamModel? get currentStream => _currentStream;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
      return true;
    }
    _errorMessage = result['message'];
    notifyListeners();
    return false;
  }

  void setCurrentStream(StreamModel? stream) {
    _currentStream = stream;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

