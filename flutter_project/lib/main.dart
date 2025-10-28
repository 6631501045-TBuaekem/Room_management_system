import 'package:flutter/material.dart';
import 'pages/loginout/login.dart';
import 'pages/common/browse.dart';
import 'pages/common/history.dart';
import 'pages/common/profile.dart';
import 'pages/common/dashboard.dart';
import 'pages/user/request.dart';
import 'pages/user/check.dart';
import 'pages/staff/manage.dart';
import 'pages/approver/approve.dart';

void main() => runApp(const RoomApp());


class RoomApp extends StatelessWidget {
  const RoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Loginpage(),
    );
  }
}

class RoomNavigation extends StatefulWidget {
  final String userRole;
  
  const RoomNavigation({super.key, required this.userRole});

  @override
  State<RoomNavigation> createState() => _RoomNavigationState();
}

class _RoomNavigationState extends State<RoomNavigation> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  void _initializeNavigation() {
    switch (widget.userRole) {
      case "0": // User
        _pages = [
          const Browseroompage(),
          const Requestroompage(),
          const Checkroompage(),
          const Historypage(),
          const Profilepage(),
        ];
        _navigationItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.outbox), label: 'Request'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Check'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
        break;
      
      case "1": // Staff
        _pages = [
          const Browseroompage(),
          const Manageroompage(),
          const Dashboardpage(),
          const Historypage(),
          const Profilepage(),
        ];
        _navigationItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Add/Edit'),
          BottomNavigationBarItem(icon: Icon(Icons.space_dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
        break;
      
      case "2": // Approver
        _pages = [
          const Browseroompage(),
          const Approvepage(),
          const Dashboardpage(),
          const Historypage(),
          const Profilepage(),
        ];
        _navigationItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Approve'),
          BottomNavigationBarItem(icon: Icon(Icons.space_dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
        break;
      
      default:
        _pages = [
          const Browseroompage(),
          const Profilepage(),
        ];
        _navigationItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _navigationItems,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
