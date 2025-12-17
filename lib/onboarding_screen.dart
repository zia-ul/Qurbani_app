import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      'title': 'Welcome to Qurbani App',
      'description': 'Easily manage and track your Qurbani activities.',
      'gif': 'assets/images/onboarding.png',
    },
    {
      'title': 'Secure & Reliable',
      'description': 'Your Qurbani details are safe and protected.',
      'gif': 'assets/video/onboarding1.gif',
    },
    {
      'title': 'Stay Updated',
      'description': 'Get notifications and real-time updates.',
      'gif': 'assets/video/onboarding1.gif',
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green, Colors.lightGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Slider
              SizedBox(
                height: screenHeight * 0.65,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    setState(() => currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // GIF with rounded corners
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              slide['gif']!,
                              height: screenHeight * 0.35,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            slide['title']!,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            slide['description']!,
                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentPage == index ? 12 : 8,
                    height: currentPage == index ? 12 : 8,
                    decoration: BoxDecoration(
                      color: currentPage == index
                          ? Colors.white
                          : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Login & Register Buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
