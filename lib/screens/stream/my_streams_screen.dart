import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stream_service.dart';
import '../../models/stream_model.dart';

class MyStreamsScreen extends StatefulWidget {
  const MyStreamsScreen({super.key});

  @override
  State<MyStreamsScreen> createState() => _MyStreamsScreenState();
}

class _MyStreamsScreenState extends State<MyStreamsScreen> {
  final StreamService _streamService = StreamService();
  List<StreamModel> _myStreams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyStreams();
  }

  Future<void> _loadMyStreams() async {
    setState(() => _isLoading = true);
    final result = await _streamService.getMyStreams();
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _myStreams = result['streams'];
      }
    });
  }

  Future<void> _endStream(String streamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Stream'),
        content: const Text('Are you sure you want to end this stream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _streamService.endStream(streamId);
      if (result['success'] == true) {
        _loadMyStreams();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stream ended successfully')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Streams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyStreams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myStreams.isEmpty
              ? const Center(
                  child: Text(
                    'No streams yet',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myStreams.length,
                  itemBuilder: (context, index) {
                    final stream = _myStreams[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (stream.isLive)
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
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'ENDED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  'Code: ${stream.streamCode}',
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              stream.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (stream.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                stream.description,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  '${stream.viewers} viewers',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(stream.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            if (stream.isLive) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _endStream(stream.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('End Stream'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

