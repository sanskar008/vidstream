import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

class WebRTCService {
  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.MediaStream? _localStream;
  webrtc.MediaStream? _remoteStream;
  webrtc.RTCVideoRenderer? _localRenderer;
  webrtc.RTCVideoRenderer? _remoteRenderer;

  final List<Function(webrtc.MediaStream)> _onRemoteStreamCallbacks = [];

  static final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> initializeLocalRenderer(webrtc.RTCVideoRenderer renderer) async {
    _localRenderer = renderer;
    await renderer.initialize();
  }

  Future<void> initializeRemoteRenderer(
    webrtc.RTCVideoRenderer renderer,
  ) async {
    _remoteRenderer = renderer;
    await renderer.initialize();
  }

  Future<webrtc.MediaStream> startLocalStream() async {
    try {
      // Use Flutter WebRTC's native camera access
      final Map<String, dynamic> constraints = {
        'audio': false,
        'video': {'facingMode': 'user'},
      };

      final stream = await webrtc.navigator.mediaDevices.getUserMedia(
        constraints,
      );

      _localStream = stream;

      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }

      return stream;
    } catch (e) {
      // Fallback: try with simpler constraints
      try {
        final Map<String, dynamic> constraints = {
          'audio': false,
          'video': true,
        };

        final stream = await webrtc.navigator.mediaDevices.getUserMedia(
          constraints,
        );

        _localStream = stream;

        if (_localRenderer != null) {
          _localRenderer!.srcObject = stream;
        }

        return stream;
      } catch (e2) {
        throw Exception('Failed to start local stream: $e2');
      }
    }
  }

  Function(webrtc.RTCIceCandidate)? onIceCandidateCallback;

  Future<void> initializePeerConnection({bool isCreator = false}) async {
    _peerConnection = await webrtc.createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (webrtc.RTCIceCandidate candidate) {
      if (onIceCandidateCallback != null) {
        onIceCandidateCallback!(candidate);
      }
    };

    // Use ontrack for newer WebRTC API
    _peerConnection!.onTrack = (webrtc.RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStream = stream;
        if (_remoteRenderer != null) {
          _remoteRenderer!.srcObject = stream;
        }
        for (var callback in _onRemoteStreamCallbacks) {
          callback(stream);
        }
      }
    };

    // Fallback to onAddStream for older API compatibility
    _peerConnection!.onAddStream = (webrtc.MediaStream stream) {
      _remoteStream = stream;
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      for (var callback in _onRemoteStreamCallbacks) {
        callback(stream);
      }
    };
  }

  Future<void> addLocalStreamToPeerConnection() async {
    if (_peerConnection == null || _localStream == null) {
      return;
    }

    try {
      // Try modern API first (addTrack)
      final tracks = _localStream!.getVideoTracks();
      for (var track in tracks) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    } catch (e) {
      // Fallback to older API (addStream)
      try {
        await _peerConnection!.addStream(_localStream!);
      } catch (e2) {
        print('Error adding stream to peer connection: $e2');
        rethrow;
      }
    }
  }

  Future<webrtc.RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      await initializePeerConnection(isCreator: true);
    }

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<webrtc.RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      await initializePeerConnection(isCreator: false);
    }

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(
    webrtc.RTCSessionDescription description,
  ) async {
    await _peerConnection?.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(webrtc.RTCIceCandidate candidate) async {
    await _peerConnection?.addCandidate(candidate);
  }

  void addRemoteStreamListener(Function(webrtc.MediaStream) callback) {
    _onRemoteStreamCallbacks.add(callback);
  }

  void removeRemoteStreamListener(Function(webrtc.MediaStream) callback) {
    _onRemoteStreamCallbacks.remove(callback);
  }

  Future<void> dispose() async {
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.dispose();
    await _localRenderer?.dispose();
    await _remoteRenderer?.dispose();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _localRenderer = null;
    _remoteRenderer = null;
    _onRemoteStreamCallbacks.clear();
  }
}
