import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';
import '../services/socket_service.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class StreamViewerWidget extends StatefulWidget {
  final String streamId;
  
  const StreamViewerWidget({
    super.key,
    required this.streamId,
  });

  @override
  State<StreamViewerWidget> createState() => _StreamViewerWidgetState();
}

class _StreamViewerWidgetState extends State<StreamViewerWidget> {
  final WebRTCService _webrtcService = WebRTCService();
  final SocketService _socketService = SocketService();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  bool _hasStream = false;
  String? _creatorId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      _socketService.connect(ApiConfig.socketUrl);
      _socketService.joinStream(widget.streamId, user.id, 'user');

      _socketService.onJoinedStream((data) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });

      _socketService.onOffer((data) async {
        _creatorId = data['fromId'];
        final offer = RTCSessionDescription(
          data['offer']['sdp'],
          data['offer']['type'],
        );
        await _webrtcService.setRemoteDescription(offer);
        final answer = await _webrtcService.createAnswer();
        if (_creatorId != null) {
          _socketService.sendAnswer(
            widget.streamId,
            {
              'sdp': answer.sdp,
              'type': answer.type,
            },
            _creatorId!,
          );
        }
      });

      _webrtcService.onIceCandidateCallback = (candidate) {
        if (_creatorId != null) {
          _socketService.sendIceCandidate(
            widget.streamId,
            {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            _creatorId!,
          );
        }
      };

      _socketService.onIceCandidate((data) async {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        );
        await _webrtcService.addIceCandidate(candidate);
      });

      _socketService.onStreamEnded(() {
        if (mounted) {
          setState(() {
            _error = 'Stream has ended';
            _hasStream = false;
            _isLoading = false;
          });
        }
      });

      _webrtcService.addRemoteStreamListener((stream) {
        if (mounted) {
          setState(() {
            _hasStream = true;
            _isLoading = false;
          });
        }
      });

      await _webrtcService.initializeRemoteRenderer(_remoteRenderer);
      await _webrtcService.initializePeerConnection(isCreator: false);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize viewer: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _socketService.leaveStream();
    }
    _socketService.disconnect();
    _webrtcService.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Connecting to stream...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (_error != null && !_hasStream) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasStream || !_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Waiting for stream...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: RTCVideoView(_remoteRenderer),
    );
  }
}

