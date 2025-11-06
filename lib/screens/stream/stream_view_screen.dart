import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/stream_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stream_provider.dart' as stream_provider;
import '../../widgets/stream_broadcaster_widget.dart';
import '../../widgets/stream_viewer_widget.dart';
import '../../widgets/stream_chat_widget.dart';

class StreamViewScreen extends StatefulWidget {
  final StreamModel stream;

  const StreamViewScreen({super.key, required this.stream});

  @override
  State<StreamViewScreen> createState() => _StreamViewScreenState();
}

class _StreamViewScreenState extends State<StreamViewScreen> {
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      final streamProvider = Provider.of<stream_provider.StreamProvider>(
        context,
        listen: false,
      );

      final isCreator =
          currentUser != null &&
          currentUser.userType == 'creator' &&
          currentUser.id == widget.stream.creator.id;

      setState(() {
        _isCreator = isCreator;
      });

      if (currentUser != null) {
        streamProvider.setCurrentStream(
          widget.stream,
          userId: currentUser.id,
          userType: currentUser.userType,
        );
        streamProvider.getLikeStatus(widget.stream.id);
        // Join stream if user is not the creator
        if (!isCreator) {
          streamProvider.joinStream(widget.stream.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stream.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share stream code functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.35,
            color: Colors.black,
            child: _isCreator
                ? StreamBroadcasterWidget(streamId: widget.stream.id)
                : StreamViewerWidget(streamId: widget.stream.id),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${widget.stream.viewers} viewers',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.stream.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.stream.creator.username,
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  if (widget.stream.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.stream.description,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Stream Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.stream.streamCode,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.stream.streamCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Stream code copied to clipboard',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<stream_provider.StreamProvider>(
                    builder: (context, streamProvider, child) {
                      final isLiked = streamProvider.isLiked(widget.stream.id);
                      final likesCount =
                          streamProvider.getLikesCount(widget.stream.id) > 0
                          ? streamProvider.getLikesCount(widget.stream.id)
                          : widget.stream.likes;

                      return Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              streamProvider.toggleLike(widget.stream.id);
                            },
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.white,
                            ),
                          ),
                          Text(
                            '$likesCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 24),
                          const Icon(
                            Icons.visibility,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.stream.viewers}',
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  StreamChatWidget(streamId: widget.stream.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
