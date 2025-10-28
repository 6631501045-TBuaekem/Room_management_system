import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// ปรับ path ให้ถูกต้องตามโครงสร้าง project ของคุณ
import '../../utills/session_cilent.dart';

// URL ฐานของ API Server
final String baseUrl = 'http://10.0.2.2:3005';

// -------------------------------------------------------------------
// Class สำหรับโครงสร้างข้อมูลจำลองของแต่ละรายการใน History
class HistoryEntry {
  final String location;
  final String timeRange;
  final String dateTime;
  final String status;
  final String user;
  final String? approvedBy;

  HistoryEntry(
    this.location,
    this.timeRange,
    this.dateTime,
    this.status,
    this.user, {
    this.approvedBy,
  });

  // Factory constructor สำหรับสร้าง object จาก JSON response ของ /history/info
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    // รวม booking_date (DD/MM/YY) และ booking_time (HH:MM) จาก API
    final String fullDateTime =
        '${json['booking_date']} ${json['booking_time']}';

    // แปลงสถานะจาก database (all lowercase) ให้ขึ้นต้นด้วยตัวใหญ่
    final String status = json['status'] as String;
    final String formattedStatus =
        status.substring(0, 1).toUpperCase() +
        status.substring(1).toLowerCase();

    // **ตรรกะสำหรับ ApprovedBy:**
    final String? approver =
        (json['approver_name'] != '-' && json['approver_name'] != null)
        ? json['approver_name'] as String?
        : null;

    return HistoryEntry(
      json['room'] as String, // location (room)
      json['booking_timeslot'] as String, // timeRange (booking_timeslot)
      fullDateTime, // dateTime
      formattedStatus, // Status (Approve/Reject/Pending)
      json['booker_name'] as String, // user (booker_name)
      approvedBy: approver, // approvedBy
    );
  }
}

// กำหนด Role Type
enum UserRole {
  Student, // role = "0"
  Staff, // role = "1"
  Approver, // role = "2"
}

class Historypage extends StatefulWidget {
  // ข้อมูล Role ที่มาจาก Login
  final UserRole userRole;
  final String currentRoleCode; // "0", "1", "2"

  const Historypage({super.key, required this.currentRoleCode})
    : userRole = (currentRoleCode == "0")
          ? UserRole.Student
          : (currentRoleCode == "1" ? UserRole.Staff : UserRole.Approver);

  @override
  State<Historypage> createState() => __HistoryState();
}

class __HistoryState extends State<Historypage> {
  final SessionHttpClient _apiClient = SessionHttpClient();
  List<HistoryEntry> _historyData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  // ฟังก์ชันสำหรับดึงข้อมูลประวัติจาก Backend
  Future<void> _fetchHistoryData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final http.Response response = await _apiClient.get(
        Uri.parse('$baseUrl/history/info'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawData = json.decode(response.body);
        _historyData = rawData
            .map((json) => HistoryEntry.fromJson(json))
            .where(
              (entry) => entry.status != 'Pending',
            ) // 👈 กรองสถานะ Pending ออก
            .toList();
      } else if (response.statusCode == 401) {
        _error = 'Unauthorized. Please login again.';
      } else {
        _error = 'Failed to load history: Status ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Connection error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget สำหรับสร้างรายการประวัติแต่ละบล็อก
  Widget _buildHistoryItem(HistoryEntry entry) {
    final bool isRejected = entry.status == 'Reject';
    final bool isStudent = widget.userRole == UserRole.Student;

    final Color statusColor = isRejected
        ? Colors.red
        : Colors.green; // ถ้าไม่ใช่ Reject ก็คือ Approve

    // **ตรรกะการแสดงผล Approve by (แถวแยกต่างหาก):**
    // แสดงเฉพาะ Staff Role "1" ที่มีการอนุมัติ/ปฏิเสธแล้วเท่านั้น
    final bool isRole1Staff = widget.currentRoleCode == "1";

    final bool shouldShowApprovedByBelow =
        isRole1Staff && entry.approvedBy != null; // ไม่ต้องเช็ค Pending แล้ว

    // กำหนดหัวข้อคอลัมน์ที่ 3 และข้อมูล
    final String thirdColumnHeader = isStudent ? 'Approve by' : 'User';
    final String thirdColumnData = isStudent
        ? (entry.approvedBy ?? '-') // ถ้า Student แสดง ApprovedBy
        : entry.user; // ถ้า Staff/Approver แสดง User

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

              // 2. Column Headers (Date/Time, status, User/Approve by)
              Row(
                children: [
                  const Expanded(
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
                  const Expanded(
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
                      thirdColumnHeader,
                      style: const TextStyle(
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
                      thirdColumnData,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              // 4. Approve by Row (แถวแยกต่างหาก - เฉพาะ Staff Role 1)
              if (shouldShowApprovedByBelow && !isStudent) ...[
                const SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Approve by ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 100),
                    Text(
                      entry.approvedBy!,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Divider ที่ด้านล่างของแต่ละบล็อก
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Divider(color: Colors.black54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      bodyContent = Center(
        child: Text(
          'Error: $_error\nRole Code: ${widget.currentRoleCode}\n\nTry checking server or login status.',
          textAlign: TextAlign.center,
        ),
      );
    } else if (_historyData.isEmpty) {
      bodyContent = const Center(
        child: Text('No history found (Only showing Approve/Reject).'),
      );
    } else {
      bodyContent = ListView.builder(
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          return _buildHistoryItem(_historyData[index]);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
        centerTitle: true,
        foregroundColor: Colors.black,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(color: Colors.grey, thickness: 1, height: 1),
        ),
      ),
      body: bodyContent,
    );
  }
}
