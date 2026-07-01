import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'customer_home_screen.dart';
import 'scheduled_rides_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({Key? key}) : super(key: key);

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CustomerHomeScreen(),
    const ScheduledRidesScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Stack(
            children: List.generate(_screens.length, (index) {
              return IgnorePointer(
                ignoring: _currentIndex != index,
                child: AnimatedOpacity(
                  opacity: _currentIndex == index ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _screens[index],
                ),
              );
            }),
          ),

          // Persistent Floating Nav Bar
          Positioned(
            bottom: 56,
            left: 24,
            right: 24,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(icon: Icons.home, index: 0),
                  _buildNavItem(icon: Icons.history, index: 1),
                  _buildNavItem(icon: Icons.account_balance_wallet, index: 2),
                  _buildNavItem(icon: Icons.person, index: 3),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    final isSelected = _currentIndex == index;

    if (isSelected) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primaryContainer, AppTheme.primary]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primaryContainer.withOpacity(0.5),
                  blurRadius: 20)
            ]),
        child: Icon(icon, color: AppTheme.onPrimaryContainer),
      );
    } else {
      return IconButton(
        icon: Icon(icon, color: AppTheme.onSurfaceVariant),
        onPressed: () {
          setState(() {
            _currentIndex = index;
          });
        },
      );
    }
  }
}
