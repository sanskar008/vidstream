import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';
import '../services/socket_service.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class StreamBroadcasterWidget extends StatefulWidget {
  final String streamId;
  
  const StreamBroadcasterWidget({
    super.key,
    required this.streamId,
  });

  @override
  State<StreamBroadcasterWidget> createState() => _StreamBroadcasterWidgetState();
}

class _StreamBroadcasterWidgetState extends State<StreamBroadcasterWidget> {
  final WebRTCService _webrtcService = WebRTCService();
  final SocketService _socketService = SocketService();
  webrtc.RTCVideoRenderer _localRenderer = webrtc.RTCVideoRenderer();
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  bool _isFrontCamera = true;
  String? _currentViewerId;

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
      _socketService.joinStream(widget.streamId, user.id, 'creator');
      
      _socketService.onViewerJoined((data) {
        _currentViewerId = data['viewerId'];
        _createOfferForViewer();
      });

      _socketService.onAnswer((data) {
        final answer = webrtc.RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        _webrtcService.setRemoteDescription(answer);
      });

      _webrtcService.onIceCandidateCallback = (candidate) {
        if (_currentViewerId != null) {
          _socketService.sendIceCandidate(
            widget.streamId,
            {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            _currentViewerId!,
          );
        }
      };

      _socketService.onIceCandidate((data) async {
        final candidate = webrtc.RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        );
        await _webrtcService.addIceCandidate(candidate);
      });

      await _webrtcService.initializeLocalRenderer(_localRenderer);
      await _requestPermissionAndStartStream();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createOfferForViewer() async {
    try {
      final offer = await _webrtcService.createOffer();
      if (_currentViewerId != null) {
        _socketService.sendOffer(
          widget.streamId,
          {
            'sdp': offer.sdp,
            'type': offer.type,
          },
          _currentViewerId!,
        );
      }
    } catch (e) {
      print('Error creating offer: $e');
    }
  }

  Future<void> _requestPermissionAndStartStream() async {
    final status = await Permission.camera.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _error = 'Camera permission is required to stream. Please enable it in settings.';
        _isLoading = false;
      });
      return;
    }

    if (status.isGranted) {
      await _startStream();
    }
  }

  Future<void> _startStream() async {
    try {
      await _webrtcService.initializePeerConnection(isCreator: true);
      await _webrtcService.startLocalStream();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to start stream: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _webrtcService.dispose();
      _isFrontCamera = !_isFrontCamera;
      await _webrtcService.initializeLocalRenderer(_localRenderer);
      await _webrtcService.initializePeerConnection(isCreator: true);
      await _webrtcService.startLocalStream();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error
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
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        SizedBox.expand(
          child: webrtc.RTCVideoView(_localRenderer, mirror: true),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _switchCamera,
            child: const Icon(Icons.flip_camera_ios),
            mini: true,
          ),
        ),
      ],
    );
  }
}

