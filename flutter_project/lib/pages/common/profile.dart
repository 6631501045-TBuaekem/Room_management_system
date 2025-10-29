import 'package:flutter/material.dart';
import 'package:flutter_project/pages/loginout/login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart'; // สำหรับกลับไปหน้า Login
import '../../utills/session_cilent.dart'; 
final session = SessionHttpClient();

class Profilepage extends StatefulWidget {
  const Profilepage({super.key});

  @override
  State<Profilepage> createState() => _ProfileState();
}

class _ProfileState extends State<Profilepage> {
  String? name;
  String? username;
  bool isLoading = true;

  final String baseUrl = "http://10.0.2.2:3005"; // ✅ Backend URL (ใช้กับ Emulator)

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ดึงข้อมูลจาก backend /profile
  Future<void> _loadProfile() async {
    try {
      final response = await session.get(Uri.parse('$baseUrl/profile'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          name = data['name'];
          username = data['username'];
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // session หมดอายุ → กลับไปหน้า login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Loginpage()),
        );
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ (${response.statusCode})')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // logout แล้วกลับไปหน้า login
  Future<void> _logout() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/logout'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result["message"] == "Logged out successful") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Loginpage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result["message"] ?? "Logout failed")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed (${response.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F6),
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                 const CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey,
                    backgroundImage: AssetImage('assets/images/avatar.jpg'),
              ),
                  const SizedBox(height: 80),

                  // Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text('Name: ',
                          style: TextStyle(
                        
                              fontWeight: FontWeight.bold, fontSize: 25)),
                      Text(name ?? '',
                          style: const TextStyle(fontSize: 25)),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Username
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text('User: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 25)),
                      Text(username ?? '',
                          style: const TextStyle(fontSize: 25)),
                    ],
                  ),

                  const SizedBox(height: 350),
                  const Divider(thickness: 1, height: 40),

                  // Logout button
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 20 ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Log out',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.white, fontWeight: FontWeight.bold)),
                            
                  ),
                ],
              ),
            ),
      // ✅ ถ้ามี Bottom Navigation อยู่ในหน้าหลัก ให้เพิ่มตรงนี้ได้
    );
  }
}