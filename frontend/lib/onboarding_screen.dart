import 'package:flutter/material.dart';
import 'package:Qurbani/theme/theme.dart';
import 'authentication/login_page.dart';
import 'authentication/register_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/banner2.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.72),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // 1. App Logo
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.bgGradientEnd,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(255, 90, 90, 90),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/images/app_logo.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 2. Title and Tagline
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        "Qurbani App",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Serif',
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Designed for Muslims seeking a simple and trusted Qurbani experience",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFF7F3E8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // const SizedBox(height: 18),

                // Container(
                //   margin: const EdgeInsets.symmetric(horizontal: 32),
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 18,
                //     vertical: 12,
                //   ),
                //   decoration: BoxDecoration(
                //     color: const Color(0xCC123524),
                //     borderRadius: BorderRadius.circular(18),
                //     border: Border.all(
                //       color: const Color(0xFFE8E6D1).withOpacity(0.7),
                //     ),
                //   ),
                //   child: const Text(
                //     "This add this for muslims only",
                //     textAlign: TextAlign.center,
                //     style: TextStyle(
                //       fontSize: 15,
                //       fontWeight: FontWeight.w600,
                //       color: Colors.white,
                //       letterSpacing: 0.3,
                //     ),
                //   ),
                // ),

                const Spacer(flex: 3),

                // 3. Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.bgGradientStart,
                            foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
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
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black.withOpacity(0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
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
                            'Sign In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 4. Branding
                const Text(
                  "powered by AI Confidence Cure",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF7F3E8),
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
