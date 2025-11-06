import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/stream_provider.dart' as stream_provider;
import '../../models/stream_model.dart';
import 'stream_view_screen.dart';

class StreamListScreen extends StatelessWidget {
  const StreamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<stream_provider.StreamProvider>(context, listen: false)
                  .fetchLiveStreams();
            },
          ),
        ],
      ),
      body: Consumer<stream_provider.StreamProvider>(
        builder: (context, streamProvider, child) {
          if (streamProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (streamProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    streamProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      streamProvider.fetchLiveStreams();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (streamProvider.liveStreams.isEmpty) {
            return const Center(
              child: Text(
                'No live streams available',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await streamProvider.fetchLiveStreams();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: streamProvider.liveStreams.length,
              itemBuilder: (context, index) {
                final stream = streamProvider.liveStreams[index];
                return _StreamCard(stream: stream);
              },
            ),
          );
        },
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  final StreamModel stream;

  const _StreamCard({required this.stream});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StreamViewScreen(stream: stream),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
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
                  const Spacer(),
                  Text(
                    '${stream.viewers} viewers',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
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
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    stream.creator.username,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, h:mm a').format(stream.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

