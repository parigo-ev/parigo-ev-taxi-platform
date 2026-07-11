import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import 'customer_main_screen.dart';
import 'wallet_screen.dart';
import 'feedback_screen.dart';
import '../widgets/send_notification_sheet.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final role = UserSession().role;
    final phone = UserSession().phone;
    if (phone.isEmpty) return;

    try {
      final url = role.toLowerCase() == 'admin'
          ? '${ApiConstants.baseUrl}/admin/notifications'
          : '${ApiConstants.baseUrl}/user/notifications/$phone';
          
      final response = await ApiClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notifications = data['notifications'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/user/notifications/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    if (UserSession().role.toLowerCase() == 'admin') return;
    
    // 1. Mark as read visually and on backend
    if (notification['is_read'] != true) {
      setState(() {
        notification['is_read'] = true;
      });
      await _markAsRead(notification['id']);
    }

    // 2. Redirect based on type
    final String type = notification['type'] ?? '';
    
    switch (type) {
      case 'ride_complete':
        if (notification['metadata'] != null) {
          try {
            final metadata = notification['metadata'] is String ? jsonDecode(notification['metadata']) : notification['metadata'];
            if (metadata['rideId'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedbackScreen(
                    role: 'Customer',
                    rideId: metadata['rideId'],
                    otherPartyName: metadata['otherPartyName'] ?? 'your driver',
                  ),
                ),
              );
              return;
            }
          } catch (e) {
            debugPrint('Failed to parse metadata: $e');
          }
        }
        break;
      case 'crash_alert':
        if (notification['metadata'] != null) {
          try {
            final metadata = notification['metadata'] is String 
                ? jsonDecode(notification['metadata']) 
                : notification['metadata'];
            final fullError = metadata['fullError'] ?? 'No error provided';
            final stackTrace = metadata['stackTrace'] ?? 'No stack trace provided';
            
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Crash Details', style: TextStyle(color: Colors.red)),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(fullError, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(stackTrace, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  )
                ],
              ),
            );
          } catch (e) {
            debugPrint('Failed to parse crash metadata: $e');
          }
        }
        break;
      case 'wallet_topup':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
        return;
      case 'welcome':
      case 'promo':
      case 'ride_assigned':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CustomerMainScreen()),
          (route) => false,
        );
        return;
      default:
        break; // Do nothing for unknown types
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'welcome': return Icons.electric_car;
      case 'promo': return Icons.local_offer;
      case 'ride_complete': return Icons.check_circle;
      case 'ride_assigned': return Icons.map;
      case 'wallet_topup': return Icons.account_balance_wallet;
      case 'crash_alert': return Icons.warning_amber_rounded;
      default: return Icons.notifications;
    }
  }

  void _openSendNotificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendNotificationSheet(
        onNotificationSent: _fetchNotifications,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = UserSession().role;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(role.toLowerCase() == 'admin' ? 'Sent Notifications' : 'Notifications', style: GoogleFonts.nunito(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      floatingActionButton: role.toLowerCase() == 'admin'
          ? FloatingActionButton.extended(
              onPressed: _openSendNotificationSheet,
              backgroundColor: AppTheme.primaryContainer,
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Send Notification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer))
            : _notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final bool isRead = n['is_read'] == true;
                      
                      // Format timeago
                      final DateTime createdAt = DateTime.parse(n['created_at']);
                      final String timeStr = timeago.format(createdAt);

                      final String recipient = n['customer_phone'] != null 
                          ? 'To: ${n['customer_name'] ?? n['customer_phone']}' 
                          : 'To: All Customers';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GestureDetector(
                          onTap: role.toLowerCase() == 'admin' ? null : () => _handleNotificationTap(n),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (isRead || role.toLowerCase() == 'admin')
                                          ? AppTheme.surfaceContainerHighest
                                          : AppTheme.primaryContainer.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getIconForType(n['type'] ?? ''),
                                      color: (isRead || role.toLowerCase() == 'admin') ? AppTheme.onSurfaceVariant : AppTheme.primaryContainer,
                                      size: 24
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n['title'] ?? 'Notification',
                                                style: TextStyle(
                                                    color: AppTheme.onSurface,
                                                    fontWeight: (isRead || role.toLowerCase() == 'admin') ? FontWeight.normal : FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                            ),
                                            Text(
                                              timeStr,
                                              style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          n['message'] ?? '',
                                          style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
                                        ),
                                        if (role.toLowerCase() == 'admin') ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            recipient,
                                            style: const TextStyle(color: AppTheme.primaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
