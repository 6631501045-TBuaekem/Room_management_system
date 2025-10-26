import 'package:flutter/material.dart';

class Dashboardpage extends StatefulWidget {
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => _DashboardpageState();
}

class _DashboardpageState extends State<Dashboardpage> {
  // ตัวอย่างข้อมูลห้อง (สามารถเปลี่ยนเป็นดึงจาก API)
  final Map<String, Map<String, dynamic>> roomStatus = {
    "Free Table": {"count": 4, "color": Color(0xFF8DB6A4)},
    "Pending Table": {"count": 3, "color": Color(0xFFF3C327)},
    "Reserve Table": {"count": 2, "color": Color(0xFF4D4E8D)},
    "Disable Room": {"count": 1, "color": Color(0xFFFE5F50)},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
        centerTitle: true,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(color: Colors.grey, thickness: 1, height: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            const Text(
              "Dashboard of all rooms : Today (18/10/2025)",
              style: TextStyle(fontSize: 25),
            ),
            const SizedBox(height: 30),
            // Grid ของกล่องสถานะ
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 50,
                mainAxisSpacing: 50,
                children: roomStatus.entries.map((entry) {
                  return Container(
                    decoration: BoxDecoration(
                      color: entry.value['color'],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value['count'].toString(),
                            style: const TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 20,
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
