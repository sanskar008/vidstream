import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/stream_model.dart';
import 'auth_service.dart';

class StreamService {
  final AuthService _authService = AuthService();

  Future<String?> _getAuthToken() async {
    return await _authService.getToken();
  }

  Future<Map<String, dynamic>> createStream({
    required String title,
    String description = '',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.streamsUrl}/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': title,
          'description': description,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'stream': StreamModel.fromJson(data['stream']),
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create stream'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getLiveStreams() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.streamsUrl}/live'),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final streams = (data['streams'] as List)
            .map((s) => StreamModel.fromJson(s))
            .toList();
        return {'success': true, 'streams': streams};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch streams'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getStreamByCode(String streamCode) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.streamsUrl}/code/$streamCode'),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'stream': StreamModel.fromJson(data['stream']),
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Stream not found'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> joinStream(String streamId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.streamsUrl}/join/$streamId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to join stream'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> endStream(String streamId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.streamsUrl}/end/$streamId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to end stream'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getMyStreams() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.streamsUrl}/my-streams'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final streams = (data['streams'] as List)
            .map((s) => StreamModel.fromJson(s))
            .toList();
        return {'success': true, 'streams': streams};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch streams'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> likeStream(String streamId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.streamsUrl}/like/$streamId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'liked': data['liked'],
          'likesCount': data['likesCount'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to like stream'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getLikeStatus(String streamId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.streamsUrl}/like-status/$streamId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'liked': data['liked'],
          'likesCount': data['likesCount'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get like status'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> resumeStream(String streamId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.streamsUrl}/resume/$streamId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'stream': StreamModel.fromJson(data['stream']),
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to resume stream'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getChatHistory(String streamId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.streamsUrl}/chat/$streamId'),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': data['messages'] ?? [],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch chat history'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }
}

