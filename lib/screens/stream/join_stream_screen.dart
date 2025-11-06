import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/stream_provider.dart' as stream_provider;
import 'stream_view_screen.dart';

class JoinStreamScreen extends StatefulWidget {
  const JoinStreamScreen({super.key});

  @override
  State<JoinStreamScreen> createState() => _JoinStreamScreenState();
}

class _JoinStreamScreenState extends State<JoinStreamScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinStream() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a stream code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final streamProvider =
        Provider.of<stream_provider.StreamProvider>(context, listen: false);
    final success = await streamProvider.getStreamByCode(code);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success && streamProvider.currentStream != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StreamViewScreen(stream: streamProvider.currentStream!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(streamProvider.errorMessage ?? 'Stream not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Stream'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter Stream Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get the code from the creator to join their stream',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    letterSpacing: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinStream,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join Stream'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

