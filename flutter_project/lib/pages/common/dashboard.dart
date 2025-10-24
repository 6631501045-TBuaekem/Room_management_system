import 'package:flutter/material.dart';

class Dashboardpage extends StatefulWidget {
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => __DashboardState();
}

class __DashboardState extends State<Dashboardpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: const Text('Browse room page'),),
    );
  }
}