import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utills/session_cilent.dart'; 
final session = SessionHttpClient();

class Registerpage extends StatefulWidget {
  const Registerpage({super.key});

  @override
  State<Registerpage> createState() => _RegisterpageState();
}

class _RegisterpageState extends State<Registerpage> {
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller3 = TextEditingController();
  final TextEditingController _controller4 = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/register.jpg'), context); // fix white screen โหลดรูปล่วงหน้าก่อน
  }

  void register() async {
      final nameInput = _controller1.text;
      final usernameInput = _controller2.text;
      final passwordInput = _controller3.text;
      final confirmPasswordInput = _controller4.text;

      if(passwordInput != confirmPasswordInput){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password doesn't match")),
        );
        return;
      }
      final body = {"name": nameInput, "username": usernameInput, "password": passwordInput, "confirm_password": confirmPasswordInput, "role": '0' };
      final url = Uri.parse('http://10.0.2.2:3005/register');
      final response = await session.post(url, body: jsonEncode(body),);
      if(response.statusCode == 200){
        Navigator.pop(context); // return to login page
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/register.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              child: Column(
                children: [
                  Text(
                    'Room Reservation',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 22,
                      color: const Color.fromARGB(255, 87, 85, 85),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Please fill the details and create account',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  TextField(
                    controller: _controller1,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'name',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _controller2,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'username',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _controller3,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'password',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _controller4,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'confirm password',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text(
                            'Sign up',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11,),
                  TextButton(
                  onPressed: (){
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Back to login',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color.fromARGB(255, 198, 212, 198),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
