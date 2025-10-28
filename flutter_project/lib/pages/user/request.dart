import 'package:flutter/material.dart';
import '../../utills/session_cilent.dart';

final session = SessionHttpClient();

class Requestroompage extends StatefulWidget {
  const Requestroompage({super.key});

  @override
  State<Requestroompage> createState() => __RequestroomState();
}

class __RequestroomState extends State<Requestroompage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: const Text('Request room page')));
  }
}
