import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utills/http_cilent.dart'; 

class Dashboardpage extends StatefulWidget {
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => _DashboardpageState();
}

class _DashboardpageState extends State<Dashboardpage> {
  Map<String, dynamic> _dashboardData = {};
  late Future<void> _fetchDataFuture;

  final Map<String, Color> colorMap = {
    "Total": Color(0xFF554440),
    "Available": Color(0xFF00A550),
    "Free": Color(0xFF8DB6A4),
    "Pending": Color(0xFFF3C327),
    "Reserved": Color(0xFF4D4E8D),
    "Disabled": Color(0xFFD62828),
  };

  final String baseUrl = "http://10.0.2.2:3005";

  @override
  void initState() {
    super.initState();
    _fetchDataFuture = fetchSlotData();
  }

  // ฟังก์ชันหลักในการดึงข้อมูลและคำนวณ Total Rooms
  Future<void> fetchSlotData() async {
    final slotUrl = Uri.parse("$baseUrl/slotdashboard");

    try {
      final response = await HttpClient.get(slotUrl); // <-- FIXED

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final free = int.tryParse("${data['freeSlots']}") ?? 0;
        final pending = int.tryParse("${data['pendingSlots']}") ?? 0;
        final reserved = int.tryParse("${data['reservedSlots']}") ?? 0;
        final disabled = int.tryParse("${data['disabledSlots']}") ?? 0;
        
        // 1. คำนวณ Active Slots
        final activeSlots = free + pending + reserved;
        // 2. คำนวณ Available Rooms (Active Slots / 4)
        int availableRooms = (activeSlots / 4).ceil();

        if (availableRooms < 0) availableRooms = 0;      // ป้องกันไม่ให้ค่าน้อยกว่าศูนย์

        // 3. คำนวณ Total Rooms (Available Rooms + Disabled Rooms)
        final totalRooms = availableRooms + disabled;

        if (!mounted) return;

        setState(() {
          _dashboardData = {
            "Total": {"count": totalRooms},
            "Available": {"count": availableRooms},
            "Free": {"count": free},
            "Pending": {"count": pending},
            "Reserved": {"count": reserved},
            "Disabled": {"count": disabled},
            "date": data["date"] ?? "N/A",
          };
        });
      } else {
        if (response.statusCode == 401) {
          throw Exception("Unauthorized — please login again.");
        }
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("Dashboard fetch error: $e");
      if (mounted) setState(() => _dashboardData = {});
      rethrow;
    }
  }

  // ฟังก์ชันที่ถูกเรียกเมื่อผู้ใช้ดึงหน้าจอลง (Pull-to-Refresh)
  Future<void> _onRefresh() async {
    setState(() {
      _fetchDataFuture = fetchSlotData();
    });
    return _fetchDataFuture;
  }

  Widget _statusTile(String key, String label) {
    final item = _dashboardData[key] ?? {};
    final count = item["count"]?.toString() ?? "0";
    final color = colorMap[key] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count,
                style: TextStyle(fontSize: 70, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 5),
            Text(label,
                style: TextStyle(fontSize: 20, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _subTile(String key, String label) {
    final count = _dashboardData[key]?["count"]?.toString() ?? "0";
    final color = colorMap[key] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, color: Colors.white)),
          ),
          Text(count,
              style: TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _totalRoomSection() {
    final totalCount = _dashboardData["Total"]?["count"]?.toString() ?? "0";

    return Container(
      height: 200,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorMap["Total"],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Rooms",
                  style: TextStyle(fontSize: 25, color: Colors.white)),
              Text(totalCount,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _subTile("Available", "Available")),
                SizedBox(width: 20),
                Expanded(child: _subTile("Disabled", "Disabled")),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _dashboardData["date"] ?? "Loading...";

    final labels = {
      "Free": "Free Slots",
      "Pending": "Pending Slots",
      "Reserved": "Reserved Slots",
    };

    return Scaffold(
      backgroundColor: Color(0xFFFBF6F4),
      appBar: AppBar(
        title: Text("Dashboard",
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(30),
            child: FutureBuilder(
              future: _fetchDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _dashboardData.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    Text("Dashboard of all rooms: Today ($date)",
                        style: TextStyle(fontSize: 20)),
                    SizedBox(height: 20),

                    _totalRoomSection(),

                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _statusTile("Free", labels["Free"]!)),
                        SizedBox(width: 20),
                        Expanded(child: _statusTile("Pending", labels["Pending"]!)),
                      ],
                    ),
                    SizedBox(height: 20),
                    _statusTile("Reserved", labels["Reserved"]!),

                    SizedBox(height: 50),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
