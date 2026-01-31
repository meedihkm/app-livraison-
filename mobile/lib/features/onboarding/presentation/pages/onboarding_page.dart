import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../../../auth/presentation/pages/login_page.dart'; // unused
import '../../../../main.dart'; // For AuthWrapper access via Route

class OnboardingPage extends StatefulWidget {
  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Bienvenue sur Awid',
      'body': 'La solution de gestion de commandes et livraisons pour les professionnels.',
      'image': 'assets/images/onboarding1.png', // Placeholder
      'icon': 'shopping_cart'
    },
    {
      'title': 'Gérez vos Commandes',
      'body': 'Passez et suivez vos commandes en temps réel, où que vous soyez.',
      'image': 'assets/images/onboarding2.png',
      'icon': 'assignment'
    },
    {
      'title': 'Mode Hors Ligne',
      'body': 'Continuez à travailler même sans connexion internet. Synchronisation automatique.',
      'image': 'assets/images/onboarding3.png',
      'icon': 'wifi_off'
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors based on current theme (we don't have ThemeProvider here yet unless we wrapped in main)
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Placeholder for image/icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIcon(_pages[index]['icon']!),
                            size: 60,
                            color: theme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 40),
                        Text(
                          _pages[index]['title']!,
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _pages[index]['body']!,
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? theme.primaryColor : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 32),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                children: [
                   if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () => _pageController.jumpToPage(_pages.length - 1),
                      child: Text('Passer'),
                    ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    child: Text(_currentPage == _pages.length - 1 ? 'Commencer' : 'Suivant'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'shopping_cart': return Icons.shopping_cart_outlined;
      case 'assignment': return Icons.assignment_outlined;
      case 'wifi_off': return Icons.wifi_off;
      default: return Icons.info;
    }
  }
}
