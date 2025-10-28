import 'package:flutter/material.dart';
import '../../utills/session_cilent.dart';

final session = SessionHttpClient();

class Checkroompage extends StatefulWidget {
  const Checkroompage({super.key});

  @override
  State<Checkroompage> createState() => __CheckroomState();
}

class __CheckroomState extends State<Checkroompage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: const Text('Check room page')));
  }
}
