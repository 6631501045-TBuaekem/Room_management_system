import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utills/http_cilent.dart';  
import '../../utills/utill.dart';     // <--- ใช้ logout() และ getToken()

class Profilepage extends StatefulWidget {
  const Profilepage({super.key});

  @override
  State<Profilepage> createState() => _ProfileState();
}

class _ProfileState extends State<Profilepage> {
  String? name;
  String? username;
  bool isLoading = true;

  final String baseUrl = "http://10.0.2.2:3005";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // โหลดข้อมูลโปรไฟล์จาก backend
  Future<void> _loadProfile() async {
    try {
      final response = await HttpClient.get(
        Uri.parse('$baseUrl/profile'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          name = data['name'];
          username = data['username'];
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        logout(context);   // <--- ใช้ util.logout()
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error ${response.statusCode}")));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey,
                    backgroundImage: AssetImage('assets/images/avatar.jpg'),
                  ),

                  const SizedBox(height: 70),

                  Row(
                    children: [
                      const Text('Name: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                      Text(name ?? '', style: const TextStyle(fontSize: 20)),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      const Text('Username: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                      Text(username ?? '', style: const TextStyle(fontSize: 20)),
                    ],
                  ),

                  const SizedBox(height: 30,),
                  const Divider(thickness: 1, height: 40),

                  // === ใช้ util.logout() ===
                  ElevatedButton(
                    onPressed: () => confirmLogout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Log out',
                      style:
                          TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
