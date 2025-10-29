import 'package:flutter/material.dart';
import '../../utills/session_cilent.dart'; 
final session = SessionHttpClient();

class Approvepage extends StatefulWidget {
  const Approvepage({super.key});

  @override
  State<Approvepage> createState() => _ApprovepageState();
}

class _ApprovepageState extends State<Approvepage> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: const Text(
          "Approver",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFFF9F7F5),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(80.0),
        child: Container(
          padding: const EdgeInsets.all(60.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Chakaporn",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "RoomA101",
                style: TextStyle(height: 2, color: Colors.black, fontSize: 25),
                
              ),
              const SizedBox(height: 4),
              const Text(
                "20 October 2025",
                style: TextStyle(fontSize: 25, color: Colors.black,height:1.5),
              ),
              const SizedBox(height: 8),
              const Text(
                "08:00 - 10:00",
                style: TextStyle(fontSize: 25, color: Colors.black),
              ),
              const Divider(
                height: 24,
                thickness: 1,
                color: Color(0xFFD3D3D3),
              ),
              const Text(
                "Reason: I want to study",
                style: TextStyle(fontSize: 25, color: Colors.black, height: 4),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 30), 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Approve",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),  
                      ),
                      child: const Text(
                        "Reject",
                        style: TextStyle(
                          
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}