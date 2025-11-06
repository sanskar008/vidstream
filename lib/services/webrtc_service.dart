import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

class WebRTCService {
  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.MediaStream? _localStream;
  webrtc.MediaStream? _remoteStream;
  webrtc.RTCVideoRenderer? _localRenderer;
  webrtc.RTCVideoRenderer? _remoteRenderer;
  bool _localStreamAdded = false;
  bool _isCreatingOffer = false;

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

  webrtc.MediaStream? getLocalStream() => _localStream;

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
    // Reset stream added flag when creating new peer connection
    _localStreamAdded = false;
    
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

    // Don't add stream multiple times
    if (_localStreamAdded) {
      print('Local stream already added to peer connection');
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
      _localStreamAdded = true;
      print('Local stream added to peer connection successfully');
    } catch (e) {
      // Fallback to older API (addStream)
      try {
        await _peerConnection!.addStream(_localStream!);
        _localStreamAdded = true;
        print('Local stream added to peer connection (fallback method)');
      } catch (e2) {
        print('Error adding stream to peer connection: $e2');
        rethrow;
      }
    }
  }

  Future<void> _resetPeerConnection() async {
    if (_peerConnection != null) {
      print('Resetting peer connection...');
      final oldConnection = _peerConnection;
      _peerConnection = null;
      _localStreamAdded = false;
      
      try {
        // Dispose the connection
        await oldConnection!.dispose();
        print('Peer connection disposed successfully');
      } catch (e) {
        print('Error disposing peer connection: $e');
        // Continue anyway - connection is already null
      }
      
      // Wait a bit to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 500));
      print('Peer connection reset complete');
    }
  }

  Future<webrtc.RTCSessionDescription> createOffer() async {
    // Prevent concurrent offer creation
    if (_isCreatingOffer) {
      throw Exception('Offer creation already in progress. Please wait.');
    }
    
    _isCreatingOffer = true;
    
    try {
      // Ensure local stream exists before creating peer connection
      if (_localStream == null) {
        throw Exception('Local stream is not available. Cannot create offer.');
      }

      // Always reset peer connection before creating a new offer
      // This ensures we never have m-line order issues
      await _resetPeerConnection();

      // Initialize fresh peer connection
      await initializePeerConnection(isCreator: true);
      
      // Ensure peer connection is created
      if (_peerConnection == null) {
        throw Exception('Failed to initialize peer connection');
      }

      // Wait a bit to ensure peer connection is fully initialized
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Ensure peer connection is ready
      if (_peerConnection == null) {
        throw Exception('Peer connection is null after initialization');
      }
      
      // Ensure local stream is added before creating offer
      if (_localStream != null && !_localStreamAdded) {
        await addLocalStreamToPeerConnection();
      }
      
      // Wait a bit to ensure stream is fully added
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Check signaling state with retry mechanism
      webrtc.RTCSignalingState? currentState;
      int retries = 0;
      const maxRetries = 5;
      
      while (retries < maxRetries) {
        try {
          currentState = _peerConnection?.signalingState;
          if (currentState != null) {
            break;
          }
        } catch (e) {
          print('Error getting signaling state (attempt ${retries + 1}): $e');
        }
        
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 200 * retries));
        }
      }
      
      print('Current signaling state before creating offer: $currentState');
      
      // If state is still null, try to proceed anyway (some implementations don't expose state immediately)
      if (currentState == null) {
        print('Warning: Signaling state is null, but proceeding with offer creation');
      } else {
        // Verify we're in stable state - this is critical
        if (currentState != webrtc.RTCSignalingState.RTCSignalingStateStable) {
          print('Warning: Not in stable state. Current: $currentState');
          // Wait longer and check again
          await Future.delayed(const Duration(milliseconds: 500));
          final newState = _peerConnection?.signalingState;
          if (newState != null && newState != webrtc.RTCSignalingState.RTCSignalingStateStable) {
            print('Still not stable after wait. State: $newState');
            // For some edge cases, we'll try to proceed anyway
            if (newState == webrtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
                newState == webrtc.RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
              throw Exception('Cannot create offer: peer connection has existing offer/answer. State: $newState');
            }
          }
        }
      }
      
      // Create offer with consistent constraints
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': true,
        'offerToReceiveAudio': false,
      });
      
      // Set local description
      await _peerConnection!.setLocalDescription(offer);
      
      // Wait for local description to be set
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify the state after setting local description
      final finalState = _peerConnection!.signalingState;
      if (finalState != webrtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print('Warning: Unexpected state after setting local description. Expected: have-local-offer, Got: $finalState');
      }
      
      print('Offer created and local description set. Type: ${offer.type}, State: $finalState');
      return offer;
    } catch (e) {
      print('Error creating offer: $e');
      print('Peer connection state: ${_peerConnection?.signalingState}');
      print('Local stream available: ${_localStream != null}');
      print('Local stream added: $_localStreamAdded');
      
      // Reset on error to ensure clean state
      await _resetPeerConnection();
      rethrow;
    } finally {
      _isCreatingOffer = false;
    }
  }

  Future<webrtc.RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      await initializePeerConnection(isCreator: false);
    }

    try {
      // Ensure we have a remote description (offer) set first
      final currentState = _peerConnection!.signalingState;
      if (currentState != webrtc.RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        print('Warning: Creating answer but not in have-remote-offer state. Current: $currentState');
        // Wait a bit and check again
        await Future.delayed(const Duration(milliseconds: 100));
        if (_peerConnection!.signalingState != webrtc.RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
          throw Exception('Cannot create answer: remote offer not set. Current state: ${_peerConnection!.signalingState}');
        }
      }
      
      final answer = await _peerConnection!.createAnswer({'offerToReceiveVideo': true, 'offerToReceiveAudio': false});
      
      // Validate answer before setting local description
      if (answer.sdp == null || answer.sdp!.isEmpty) {
        throw Exception('Created answer has invalid SDP');
      }
      
      if (answer.type == null || answer.type!.toLowerCase() != 'answer') {
        throw Exception('Created answer has invalid type: ${answer.type}');
      }
      
      await _peerConnection!.setLocalDescription(answer);
      
      // Wait for local description to be set
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('Answer created and local description set. Type: ${answer.type}, State: ${_peerConnection!.signalingState}');
      return answer;
    } catch (e) {
      print('Error creating answer: $e');
      rethrow;
    }
  }

  Future<void> setRemoteDescription(
    webrtc.RTCSessionDescription description,
  ) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection is not initialized');
    }
    
    // Validate SDP
    if (description.sdp == null || description.sdp!.isEmpty) {
      throw Exception('Invalid SDP: SDP is null or empty');
    }
    
    if (description.type == null || description.type!.isEmpty) {
      throw Exception('Invalid description type: type is null or empty');
    }
    
    try {
      // Check current state and validate
      final currentState = _peerConnection!.signalingState;
      print('Current signaling state: $currentState');
      print('Setting remote description type: ${description.type}');
      print('SDP length: ${description.sdp?.length ?? 0}');
      
      // Validate state before setting remote description
      if (description.type!.toLowerCase() == 'answer') {
        // For answer, we should be in "have-local-offer" state
        if (currentState != webrtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          print('Warning: Unexpected state for answer. Current: $currentState, Expected: have-local-offer');
          
          // If we're in stable state, we might need to wait a bit
          if (currentState == webrtc.RTCSignalingState.RTCSignalingStateStable) {
            print('Waiting for local offer to be set...');
            await Future.delayed(const Duration(milliseconds: 200));
            // Check again
            if (_peerConnection!.signalingState != webrtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
              throw Exception('Cannot set remote answer: peer connection is not in have-local-offer state. Current state: $currentState');
            }
          } else {
            throw Exception('Cannot set remote answer: peer connection is in wrong state. Current: $currentState, Expected: have-local-offer');
          }
        }
      } else if (description.type!.toLowerCase() == 'offer') {
        // For offer, we should be in "stable" state
        if (currentState != webrtc.RTCSignalingState.RTCSignalingStateStable) {
          print('Warning: Unexpected state for offer. Current: $currentState, Expected: stable');
        }
      }
      
      // Create a new RTCSessionDescription to ensure proper format
      final sessionDescription = webrtc.RTCSessionDescription(
        description.sdp!,
        description.type!,
      );
      
      await _peerConnection!.setRemoteDescription(sessionDescription);
      print('Remote description set successfully. New state: ${_peerConnection!.signalingState}');
    } catch (e) {
      print('Error setting remote description: $e');
      print('Signaling state: ${_peerConnection!.signalingState}');
      print('Connection state: ${_peerConnection!.connectionState}');
      print('Description type: ${description.type}');
      print('SDP preview: ${description.sdp?.substring(0, description.sdp!.length > 100 ? 100 : description.sdp!.length)}...');
      rethrow;
    }
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
    _localStreamAdded = false;
    _onRemoteStreamCallbacks.clear();
  }
}
