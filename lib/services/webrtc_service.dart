import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  final List<Function(MediaStream)> _onRemoteStreamCallbacks = [];

  static final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> initializeLocalRenderer(RTCVideoRenderer renderer) async {
    _localRenderer = renderer;
    await renderer.initialize();
  }

  Future<void> initializeRemoteRenderer(RTCVideoRenderer renderer) async {
    _remoteRenderer = renderer;
    await renderer.initialize();
  }

  Future<MediaStream> startLocalStream() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'video': {'facingMode': 'user'},
        'audio': false,
      });

      _localStream = stream;

      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }

      return stream;
    } catch (e) {
      // Fallback: try without facingMode specification
      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'video': true,
          'audio': false,
        });

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

  Function(RTCIceCandidate)? onIceCandidateCallback;

  Future<void> initializePeerConnection({bool isCreator = false}) async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (onIceCandidateCallback != null) {
        onIceCandidateCallback!(candidate);
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      for (var callback in _onRemoteStreamCallbacks) {
        callback(stream);
      }
    };

    if (isCreator && _localStream != null) {
      _peerConnection!.addStream(_localStream!);
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      await initializePeerConnection(isCreator: true);
    }

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      await initializePeerConnection(isCreator: false);
    }

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection?.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection?.addCandidate(candidate);
  }

  void addRemoteStreamListener(Function(MediaStream) callback) {
    _onRemoteStreamCallbacks.add(callback);
  }

  void removeRemoteStreamListener(Function(MediaStream) callback) {
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
