import 'package:flutter/material.dart';

class Dashboardpage extends StatefulWidget {
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => _DashboardpageState();
}

class _DashboardpageState extends State<Dashboardpage> {
  // ตัวอย่างข้อมูลห้อง (สามารถเปลี่ยนเป็นดึงจาก API)
  final Map<String, Map<String, dynamic>> roomStatus = {
    "Free": {"count": 4, "color": Colors.green[300]},
    "Pending": {"count": 3, "color": Colors.amber[400]},
    "Reserve": {"count": 2, "color": Colors.deepPurple[300]},
    "Disable": {"count": 1, "color": Colors.red[300]},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard of all rooms : Today (18/10/2025)",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            // Grid ของกล่องสถานะ
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: roomStatus.entries.map((entry) {
                  return Container(
                    decoration: BoxDecoration(
                      color: entry.value['color'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value['count'].toString(),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
