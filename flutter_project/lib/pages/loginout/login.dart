import 'package:flutter/material.dart';
import 'dart:convert';
import '../../main.dart';
import 'register.dart';
import '../../utills/session_cilent.dart';

final session = SessionHttpClient();

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/login.jpg'), context);
  }

  Future<void> login() async {
    final body = {
      "username": _usernameCtrl.text.trim(),
      "password": _passwordCtrl.text.trim(),
    };

    final url = Uri.parse('http://10.0.2.2:3005/login');
    final response = await session.post(url, body: jsonEncode(body));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final userRole = data['role'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoomNavigation(userRole: userRole)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.body)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/images/login.jpg'),
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay for readability
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),

          // Foreground content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                children: [
                  // Title
                  const Text(
                    'Room Reservation',
                    style: TextStyle(
                      fontSize: 35,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Subtitle
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Enter your username and password to sign in',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  // Username input
                  _buildTextField(
                    controller: _usernameCtrl,
                    hint: 'Username',
                    isPassword: false,
                  ),
                  const SizedBox(height: 12),

                  // Password input
                  _buildTextField(
                    controller: _passwordCtrl,
                    hint: 'Password',
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),

                  // Sign-in button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: const [
                      Expanded(child: Divider(color: Colors.white54)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'or',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white54)),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Sign-up section
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Registerpage()),
                    ),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color.fromARGB(255, 250, 250, 250),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isPassword,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
