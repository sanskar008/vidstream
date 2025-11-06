import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  UserModel? _viewedProfile;
  List<UserModel> _followers = [];
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get viewedProfile => _viewedProfile;
  List<UserModel> get followers => _followers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUserProfile(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _profileService.getUserProfile(userId);

    _isLoading = false;

    if (result['success'] == true) {
      _viewedProfile = result['user'];
      _errorMessage = null;
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
  }

  Future<bool> followUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _profileService.followUser(userId);

    _isLoading = false;

    if (result['success'] == true) {
      if (_viewedProfile != null && _viewedProfile!.id == userId) {
        _viewedProfile = UserModel(
          id: _viewedProfile!.id,
          username: _viewedProfile!.username,
          email: _viewedProfile!.email,
          userType: _viewedProfile!.userType,
          followersCount: _viewedProfile!.followersCount + 1,
          followingCount: _viewedProfile!.followingCount,
          liveStreams: _viewedProfile!.liveStreams,
        );
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  Future<bool> unfollowUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _profileService.unfollowUser(userId);

    _isLoading = false;

    if (result['success'] == true) {
      if (_viewedProfile != null && _viewedProfile!.id == userId) {
        _viewedProfile = UserModel(
          id: _viewedProfile!.id,
          username: _viewedProfile!.username,
          email: _viewedProfile!.email,
          userType: _viewedProfile!.userType,
          followersCount: _viewedProfile!.followersCount - 1,
          followingCount: _viewedProfile!.followingCount,
          liveStreams: _viewedProfile!.liveStreams,
        );
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchFollowersList() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _profileService.getFollowersList();

    _isLoading = false;

    if (result['success'] == true) {
      _followers = result['followers'];
      _errorMessage = null;
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

