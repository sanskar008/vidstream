import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message_model.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';

class StreamChatWidget extends StatefulWidget {
  final String streamId;

  const StreamChatWidget({
    super.key,
    required this.streamId,
  });

  @override
  State<StreamChatWidget> createState() => _StreamChatWidgetState();
}

class _StreamChatWidgetState extends State<StreamChatWidget> {
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    _socketService.connect(ApiConfig.socketUrl);
    _socketService.onChatMessage((data) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessageModel.fromJson(data));
        });
        _scrollToBottom();
      }
    });

    _socketService.onJoinedStream((data) {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
      }
    });

    _socketService.joinStream(widget.streamId, user.id, user.userType);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      _socketService.sendChatMessage(
        widget.streamId,
        message,
        user.id,
        user.username,
      );
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _socketService.removeAllListeners();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    return Container(
      constraints: BoxConstraints(
        minHeight: 400,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF334155), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Live Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_messages.length}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Be the first to chat!',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isOwnMessage =
                          currentUser?.id == message.userId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isOwnMessage
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isOwnMessage) ...[
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF6366F1),
                                child: Text(
                                  message.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isOwnMessage
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isOwnMessage)
                                      Text(
                                        message.username,
                                        style: const TextStyle(
                                          color: Color(0xFF6366F1),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (!isOwnMessage)
                                      const SizedBox(height: 4),
                                    Text(
                                      message.message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isOwnMessage) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF6366F1),
                                child: Text(
                                  currentUser?.username[0].toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF334155), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF334155),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

