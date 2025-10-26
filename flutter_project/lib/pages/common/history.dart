import 'package:flutter/material.dart';

// Class สำหรับโครงสร้างข้อมูลจำลองของแต่ละรายการใน History
class HistoryEntry {
  final String location;
  final String timeRange;
  final String dateTime;
  final String status;
  final String user;
  final String? approvedBy; // เพิ่ม field สำหรับ Approved by

  HistoryEntry(
    this.location,
    this.timeRange,
    this.dateTime,
    this.status,
    this.user, {
    this.approvedBy,
  });
}

class Historypage extends StatefulWidget {
  const Historypage({super.key});

  @override
  State<Historypage> createState() => __HistoryState();
}

class __HistoryState extends State<Historypage> {
  // ข้อมูลจำลองตามรูปภาพ
  final List<HistoryEntry> _historyData = [
    HistoryEntry(
      'C1 301',
      '08:00 - 10:00',
      '2/11/25 22:00',
      'Reject',
      'jeans',
      approvedBy: 'sadboy',
    ),
    HistoryEntry(
      'C1 301',
      '08:00 - 10:00',
      '2/11/25 22:00',
      'Approve',
      'jeans',
      approvedBy: 'sadboy',
    ), // แก้เป็น Approve
  ];

  // Widget สำหรับสร้างรายการประวัติแต่ละบล็อก
  Widget _buildHistoryItem(HistoryEntry entry) {
    final bool isRejected = entry.status == 'Reject';
    final Color statusColor = isRejected
        ? Colors.red
        : const Color.fromARGB(255, 34, 139, 34); // สีเขียวเข้ม

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Location and Time Header (Centered)
              Center(
                child: Column(
                  children: [
                    Text(
                      entry.location,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
                    Text(entry.timeRange, style: const TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 2. Column Headers (Date/Time, status, User)
              const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Date/Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'User',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 3. Data Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.dateTime,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      entry.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.user,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30), // เพิ่มระยะห่าง
              // 4. Approve by Row (ถ้ามีข้อมูล)
              if (entry.approvedBy != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Approve by',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 150),

                    Text(
                      entry.approvedBy!,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // เพิ่ม Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Divider(color: Colors.black),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
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

      body: ListView.builder(
        // ใช้ ListView.builder แทน ListView.separated
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          return _buildHistoryItem(_historyData[index]);
        },
      ),
    );
  }
}
