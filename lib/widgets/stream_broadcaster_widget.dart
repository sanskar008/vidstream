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
  bool _offerSent = false;

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
      
      _socketService.onViewerJoined((data) async {
        if (mounted && _isInitialized) {
          print('Viewer joined: ${data['viewerId']}');
          
          // If we're already waiting for an answer, wait a bit before creating new offer
          if (_offerSent) {
            print('Waiting for previous offer answer before creating new offer...');
            // Wait for answer or timeout
            await Future.delayed(const Duration(seconds: 5));
            // If still waiting, we'll create a new offer (previous viewer might have disconnected)
            if (_offerSent && mounted) {
              print('Previous offer timed out, creating new offer for new viewer');
              _offerSent = false;
            }
          }
          
          _currentViewerId = data['viewerId'];
          
          // Ensure local stream is started before creating offer
          try {
            await _createOfferForViewer();
          } catch (e) {
            print('Error creating offer for viewer: $e');
            if (mounted) {
              setState(() {
                _error = 'Failed to connect to viewer: $e';
              });
            }
          }
        } else {
          print('Cannot create offer: stream not initialized. Initialized: $_isInitialized, Mounted: $mounted');
        }
      });

      _socketService.onAnswer((data) async {
        try {
          if (!mounted || !_isInitialized) {
            print('Cannot process answer: stream not initialized');
            return;
          }
          
          // Only process answer if we've sent an offer
          if (!_offerSent) {
            print('Received answer but no offer was sent yet. Ignoring.');
            return;
          }
          
          print('Received answer from viewer: ${data['fromId']}');
          
          // Validate answer data
          if (data['answer'] == null || 
              data['answer']['sdp'] == null || 
              data['answer']['type'] == null) {
            throw Exception('Invalid answer format');
          }
          
          final sdp = data['answer']['sdp'] as String;
          final type = data['answer']['type'] as String;
          
          // Validate SDP and type
          if (sdp.isEmpty) {
            throw Exception('Answer SDP is empty');
          }
          
          if (type.toLowerCase() != 'answer') {
            throw Exception('Invalid answer type: $type');
          }
          
          final answer = webrtc.RTCSessionDescription(sdp, type);
          
          print('Setting remote description with answer. Type: ${answer.type}, SDP length: ${sdp.length}');
          await _webrtcService.setRemoteDescription(answer);
          print('Answer processed successfully');
          _offerSent = false; // Reset for next viewer
        } catch (e) {
          print('Error setting remote description: $e');
          _offerSent = false;
          if (mounted) {
            setState(() {
              _error = 'Failed to process answer: ${e.toString()}';
            });
          }
        }
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
      
      // After stream is started, check if there are already viewers waiting
      _socketService.onJoinedStream((data) {
        // Stream is ready, check for waiting viewers
        if (mounted && _isInitialized) {
          // The backend will send viewer-joined events for existing viewers
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createOfferForViewer() async {
    try {
      if (!mounted || !_isInitialized) {
        print('Cannot create offer: stream not initialized');
        return;
      }
      
      if (_currentViewerId == null) {
        print('Cannot create offer: no viewer ID');
        return;
      }
      
      print('Creating offer for viewer: $_currentViewerId');
      _offerSent = false;
      
      final offer = await _webrtcService.createOffer();
      
      if (_currentViewerId != null && mounted) {
        _socketService.sendOffer(
          widget.streamId,
          {
            'sdp': offer.sdp,
            'type': offer.type,
          },
          _currentViewerId!,
        );
        _offerSent = true;
        print('Offer sent to viewer: $_currentViewerId');
        
        // Set timeout for answer
        Future.delayed(const Duration(seconds: 10), () {
          if (_offerSent && mounted) {
            print('Offer timeout: no answer received from viewer $_currentViewerId');
            _offerSent = false;
          }
        });
      }
    } catch (e) {
      print('Error creating offer: $e');
      _offerSent = false;
      if (mounted) {
        setState(() {
          _error = 'Failed to create offer: $e';
        });
      }
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
      // Start the local stream first (camera) - this works independently
      await _webrtcService.startLocalStream();
      
      // Note: We don't create peer connection here - only create it when a viewer joins
      // This ensures the camera stays active even without viewers
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        print('Stream started successfully. Camera is active. Waiting for viewers...');
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
      // Dispose current stream but keep renderer
      final currentStream = _webrtcService.getLocalStream();
      await currentStream?.dispose();
      
      _isFrontCamera = !_isFrontCamera;
      
      // Restart stream with new camera
      await _webrtcService.startLocalStream();
      
      // Update renderer - the startLocalStream already sets it, but ensure it's updated
      final newStream = _webrtcService.getLocalStream();
      if (newStream != null && mounted) {
        _localRenderer.srcObject = newStream;
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error switching camera: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to switch camera: $e';
        });
      }
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

