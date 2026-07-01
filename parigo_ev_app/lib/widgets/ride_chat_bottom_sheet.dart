import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class RideChatBottomSheet extends StatefulWidget {
  final String rideId;
  final String role; // 'Customer' or 'Driver'

  const RideChatBottomSheet({
    super.key,
    required this.rideId,
    required this.role,
  });

  @override
  State<RideChatBottomSheet> createState() => _RideChatBottomSheetState();
}

class _RideChatBottomSheetState extends State<RideChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _pollingTimer;
  bool _isLoading = true;

  final List<String> _customerQuickReplies = [
    "I'm here",
    "On my way",
    "Please call me",
    "Waiting outside"
  ];

  final List<String> _driverQuickReplies = [
    "I've arrived",
    "Stuck in traffic",
    "Please come outside",
    "On my way"
  ];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(isBackground: true);
    });
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConstants.baseUrl}/rides/${widget.rideId}/messages'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (mounted) {
            setState(() {
              final oldLength = _messages.length;
              _messages = List<Map<String, dynamic>>.from(data['messages']);
              if (!isBackground) _isLoading = false;
              if (isBackground && _messages.length > oldLength) {
                _scrollToBottom();
              }
            });
            if (!isBackground) {
              _scrollToBottom();
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
      if (mounted && !isBackground) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final optimisticMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'senderRole': widget.role,
      'text': text,
    };

    setState(() {
      _messages.add(optimisticMessage);
    });
    _messageController.clear();
    _scrollToBottom();
    
    _pollingTimer?.cancel();

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/rides/${widget.rideId}/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderRole': widget.role,
          'text': text.trim(),
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to send message');
      }
      _fetchMessages(isBackground: true);
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        _startPolling();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quickReplies = widget.role == 'Customer'
        ? _customerQuickReplies
        : _driverQuickReplies;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chat with ${widget.role == 'Customer' ? 'Driver' : 'Customer'}',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.surfaceContainerHighest),

          // Message List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nSay hello!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['senderRole'] == widget.role;

                          return Align(
                            alignment:
                                isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppTheme.primary
                                    : AppTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 16),
                                ),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: GoogleFonts.nunito(
                                  color: isMe
                                      ? AppTheme.onPrimary
                                      : AppTheme.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Quick Replies
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: quickReplies.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(quickReplies[index]),
                    labelStyle: const TextStyle(color: AppTheme.primary),
                    backgroundColor: AppTheme.primaryContainer.withOpacity(0.3),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () => _sendMessage(quickReplies[index]),
                  ),
                );
              },
            ),
          ),

          // Input Field
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom == 0
                  ? MediaQuery.of(context).padding.bottom + 16
                  : MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.onPrimaryContainer),
                    onPressed: () => _sendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
