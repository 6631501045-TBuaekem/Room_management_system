import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utills/session_cilent.dart'; // นำเข้า SessionHttpClient

// 🟢 Global Singleton Instance: ใช้ตัวเดียวกับที่ Loginpage ใช้งาน
final session = SessionHttpClient();

class Dashboardpage extends StatefulWidget {
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => _DashboardpageState();
}

class _DashboardpageState extends State<Dashboardpage> {
  // ใช้ Map<String, dynamic> เก็บข้อมูลที่ได้จาก API
  Map<String, dynamic> _dashboardData = {};

  // 🟢 ใช้ Future<void> ที่สามารถถูกอัปเดตได้
  late Future<void> _fetchDataFuture;

  final Map<String, Color> colorMap = {
    "Total": const Color(0xFF554440),
    "Available": const Color(0xFF00A550),
    "Free": const Color(0xFF8DB6A4),
    "Pending": const Color(0xFFF3C327),
    "Reserved": const Color(0xFF4D4E8D),
    "Disabled": const Color(0xFFD62828),
  };

  final String baseUrl = 'http://10.0.2.2:3005';

  @override
  void initState() {
    super.initState();
    _fetchDataFuture = fetchSlotData();
  }

  // ฟังก์ชันหลักในการดึงข้อมูลและคำนวณ Total Rooms
  Future<void> fetchSlotData() async {
    final slotUrl = Uri.parse('$baseUrl/slotdashboard');
    int totalRoomsCount;
    int availableRoomsCount;

    try {
      final response = await session.get(slotUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final int freeCount =
            int.tryParse(data['freeSlots']?.toString() ?? '0') ?? 0;
        final int pendingCount =
            int.tryParse(data['pendingSlots']?.toString() ?? '0') ?? 0;
        final int reservedCount =
            int.tryParse(data['reservedSlots']?.toString() ?? '0') ?? 0;
        final int disabledRoomsCount =
            int.tryParse(data['disabledSlots']?.toString() ?? '0') ?? 0;

        // 1. คำนวณ Active Slots
        final int activeSlotsCount = freeCount + pendingCount + reservedCount;

        // 2. คำนวณ Available Rooms (Active Slots / 4)
        availableRoomsCount = (activeSlotsCount / 4).ceil();

        // 3. คำนวณ Total Rooms (Available Rooms + Disabled Rooms)
        totalRoomsCount = availableRoomsCount + disabledRoomsCount;

        // ป้องกันไม่ให้ค่าน้อยกว่าศูนย์
        if (availableRoomsCount < 0) {
          availableRoomsCount = 0;
        }

        if (mounted) {
          setState(() {
            _dashboardData = {
              "Total": {"count": totalRoomsCount, "key": "Total"},
              "Available": {"count": availableRoomsCount, "key": "Available"},
              "Free": {"count": freeCount, "key": "Free"},
              "Pending": {"count": pendingCount, "key": "Pending"},
              "Reserved": {"count": reservedCount, "key": "Reserved"},
              "Disabled": {"count": disabledRoomsCount, "key": "Disabled"},
              "date": data['date'] ?? 'N/A',
            };
          });
        }
      } else {
        if (response.statusCode == 401) {
          throw Exception('Authorization required. Please log in first.');
        }
        throw Exception(
          'Failed to load data from API (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _dashboardData = {};
        });
      }
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

  // Widget (Free, Pending, Reserved)
  Widget _buildStatusTile(String key, String label, Map<String, dynamic> data) {
    final item = data[key] as Map<String, dynamic>?;
    final count = item?['count']?.toString() ?? '0';
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 70,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  //  Widget Total Room (Available/Disabled)
  Widget _buildSubTile(String key, String label, Map<String, dynamic> data) {
    final item = data[key] as Map<String, dynamic>?;
    final count = item?['count']?.toString() ?? '0';
    final color = colorMap[key] ?? Colors.grey;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              count,
              style: const TextStyle(
                fontSize: 25,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Total Room
  Widget _buildTotalRoomSection(Map<String, dynamic> data) {
    // Total และ Disabled ที่คำนวณ/ดึงมา
    final totalItem = data['Total'] as Map<String, dynamic>?;
    final totalCount = totalItem?['count']?.toString() ?? '0';
    final totalColor = colorMap['Total'] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      height: 200,
      decoration: BoxDecoration(
        color: totalColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black, width: 2), // ขอบดำ
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row แรก: Total Room Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Room',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                totalCount,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Row ที่สอง: Available และ Disable Tiles
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildSubTile("Available", "Available Rooms", data),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSubTile("Disabled", "Disable Rooms", data),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = _dashboardData['date'] ?? 'Loading...';

    // Labels สำหรับสถานะที่เหลือ
    final Map<String, String> tileLabels = {
      "Free": "Free Slots",
      "Pending": "Pending Slots",
      "Reserved": "Reserve Slots",
    };
    final List<String> tileKeys = ["Free", "Pending", "Reserved"];

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6F4),
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
        centerTitle: true,
        foregroundColor: Colors.black,
        backgroundColor: Colors.transparent, // ทำให้ App Bar โปร่งใส
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(color: Colors.grey, thickness: 1, height: 1),
        ),
      ),
      // 🟢 ห่อ body ด้วย RefreshIndicator
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(30.0), // ลด Padding ด้านข้าง
            child: FutureBuilder(
              future: _fetchDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _dashboardData.isEmpty) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          (Scaffold.of(context).appBarMaxHeight ?? 0) -
                          100,
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError && _dashboardData.isEmpty) {
                  // แสดง Error Widget... (โค้ดเดิม)
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          (Scaffold.of(context).appBarMaxHeight ?? 0) -
                          100,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Failed to load data from API: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _onRefresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // ส่วนแสดงผล
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ส่วนแสดงวันที่
                    const SizedBox(height: 5),
                    Text(
                      "Dashboard of all rooms : Today ($displayDate)",
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 20),

                    // 1. กล่องใหญ่ Total Room
                    _buildTotalRoomSection(_dashboardData),

                    // 2. กล่องสถานะย่อย (Free, Pending, Reserved)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // กล่อง Free
                        Expanded(
                          flex: 2,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _buildStatusTile(
                              tileKeys[0],
                              tileLabels[tileKeys[0]]!,
                              _dashboardData,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // กล่อง Pending
                        Expanded(
                          flex: 2,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _buildStatusTile(
                              tileKeys[1],
                              tileLabels[tileKeys[1]]!,
                              _dashboardData,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Row ที่สอง: Reserved (ยาวเต็มความกว้าง)
                    AspectRatio(
                      aspectRatio: 2.5,
                      child: _buildStatusTile(
                        tileKeys[2],
                        tileLabels[tileKeys[2]]!,
                        _dashboardData,
                      ),
                    ),

                    // เพิ่ม SizedBox เพื่อให้มีพื้นที่ว่างด้านล่างสำหรับการดึง
                    const SizedBox(height: 50),
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
