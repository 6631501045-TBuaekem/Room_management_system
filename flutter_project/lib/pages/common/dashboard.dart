import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utills/session_cilent.dart'; // นำเข้า SessionHttpClient

// 🟢 Global Singleton Instance: ใช้ตัวเดียวกับที่ Loginpage ใช้งาน
final session = SessionHttpClient();

class Dashboardpage extends StatefulWidget {
  // 🔴 Constructor ถูกคงไว้ตามที่ร้องขอ
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => _DashboardpageState();
}

class _DashboardpageState extends State<Dashboardpage> {
  // ใช้ Map<String, dynamic> เก็บข้อมูลที่ได้จาก API
  Map<String, dynamic> _dashboardData = {};

  // 🟢 ใช้ Future<void> ที่สามารถถูกอัปเดตได้
  late Future<void> _fetchDataFuture;

  // โค้ดสีตามที่คุณต้องการ (คงที่ไว้ใน State)
  final Map<String, Color> colorMap = {
    "Free": const Color(0xFF8DB6A4),
    "Pending": const Color(0xFFF3C327),
    "Reserved": const Color(0xFF4D4E8D),
    "Disabled": const Color(0xFFFE5F50),
  };

  // ฐาน URL ของ API ของคุณ (ใช้ IP สำหรับ Android Emulator)
  final String baseUrl = 'http://10.0.2.2:3005';

  @override
  void initState() {
    super.initState();
    // เริ่มต้นดึงข้อมูลเมื่อเข้าสู่หน้า
    _fetchDataFuture = fetchSlotData();
  }

  // 🟢 ฟังก์ชันหลักในการดึงข้อมูล
  Future<void> fetchSlotData() async {
    try {
      final url = Uri.parse('$baseUrl/slotdashboard');

      // 🟢 ใช้ Global session.get() เพื่อส่ง Cookie/Session
      final response = await session.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // การแปลงข้อมูลจาก API
        final int freeCount =
            int.tryParse(data['freeSlots']?.toString() ?? '0') ?? 0;
        final int pendingCount =
            int.tryParse(data['pendingSlots']?.toString() ?? '0') ?? 0;
        final int reservedCount =
            int.tryParse(data['reservedSlots']?.toString() ?? '0') ?? 0;
        final int disabledCount =
            int.tryParse(data['disabledSlots']?.toString() ?? '0') ?? 0;

        if (mounted) {
          setState(() {
            _dashboardData = {
              "Free": {"count": freeCount, "key": "Free"},
              "Pending": {"count": pendingCount, "key": "Pending"},
              "Reserved": {"count": reservedCount, "key": "Reserved"},
              "Disabled": {"count": disabledCount, "key": "Disabled"},
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

  // 🟢 ฟังก์ชันที่ถูกเรียกเมื่อผู้ใช้ดึงหน้าจอลง (Pull-to-Refresh)
  Future<void> _onRefresh() async {
    setState(() {
      _fetchDataFuture = fetchSlotData();
    });
    return _fetchDataFuture;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> statusKeys = ["Free", "Pending", "Reserved", "Disabled"];

    final List<Map<String, dynamic>> gridItems = statusKeys
        .map((key) => _dashboardData[key])
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();

    final String displayDate = _dashboardData['date'] ?? 'Loading...';

    final Map<String, String> labelMap = {
      "Free": "Free Table",
      "Pending": "Pending Table",
      "Reserved": "Reserve Table",
      "Disabled": "Disable Room",
    };

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
      // 🟢 ห่อ body ด้วย RefreshIndicator
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          // 🔴 ส่วนสำคัญ: บังคับให้ Scroll ได้เสมอ
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(50.0),
            child: FutureBuilder(
              future: _fetchDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _dashboardData.isEmpty) {
                  // ใช้ ConstrainedBox เพื่อให้ Center กินพื้นที่หน้าจอเมื่อ Loading
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
                  // เมื่อมี Error, ทำให้ Column สูงพอที่จะดึงลงมาได้
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
                              'ไม่สามารถเชื่อมต่อ API หรือดึงข้อมูลได้: ${snapshot.error}',
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
                              label: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // 🟢 ส่วนแสดงผล (ถ้าสำเร็จ)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize:
                      MainAxisSize.min, // ให้ Column ใช้พื้นที่ตามเนื้อหา
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      "Dashboard of all rooms : Today ($displayDate)",
                      style: const TextStyle(fontSize: 25),
                    ),
                    const SizedBox(height: 30),

                    // 🔴 AspectRatio และ GridView เพื่อแสดง 4 กล่องได้อย่างถูกต้อง
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: GridView.count(
                        shrinkWrap: true, // ใช้พื้นที่เท่าที่จำเป็น
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 50,
                        mainAxisSpacing: 50,
                        children: gridItems.map((item) {
                          final statusKey = item['key'];
                          return Container(
                            decoration: BoxDecoration(
                              color: colorMap[statusKey],
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['count'].toString(),
                                    style: const TextStyle(
                                      fontSize: 80,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    labelMap[statusKey] ?? statusKey,
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
                    // 🟢 เพิ่ม SizedBox เพื่อให้มีพื้นที่ว่างด้านล่างสำหรับการดึง
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
