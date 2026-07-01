import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Best EV Taxi Service in Your City",
      "subtitle":
          "Premium electric taxis at your fingertips. Smooth, silent, and lightning-fast rides anywhere in the city.",
      "image": "assets/images/onboarding_1.png"
    },
    {
      "title": "Ride Booked = Ride Confirmed",
      "subtitle":
          "When you book with Parigo, your ride is locked in. No surprises, no cancellations - just confirmed every single time.",
      "image": "assets/images/onboarding_2.png"
    },
    {
      "title": "Ride & Reduce CO2 from Environment",
      "subtitle":
          "Every Parigo ride helps lower carbon emissions. Choose green, choose clean - make every kilometer count.",
      "image": "assets/images/onboarding_3.png"
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const LoginScreen(role: 'Customer')),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const LoginScreen(role: 'Customer')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.3),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(flex: 1),
                            // Image
                            Flexible(
                              flex: 5,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 380),
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.2),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  _onboardingData[index]["image"]!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const Spacer(flex: 1),
                            // Glass Card Text Container
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTheme.outline),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _onboardingData[index]["title"]!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _onboardingData[index]["subtitle"]!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Progress Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 10,
                            width: _currentPage == index ? 30 : 10,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppTheme.primaryContainer
                                  : AppTheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryContainer
                                            .withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Next/Get Started Button
                      InkWell(
                        onTap: _nextPage,
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryContainer,
                                AppTheme.primary
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.primaryContainer.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _onboardingData.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: const TextStyle(
                                  color: AppTheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward,
                                  color: AppTheme.onPrimaryContainer, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Skip Button
                      if (_currentPage < _onboardingData.length - 1)
                        TextButton(
                          onPressed: _skip,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 48), // Keep spacing consistent
                    ],
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
