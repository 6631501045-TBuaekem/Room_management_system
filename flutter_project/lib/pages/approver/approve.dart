import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utills/session_cilent.dart';

final session = SessionHttpClient();

class Approvepage extends StatefulWidget {
  const Approvepage({super.key});

  @override
  State<Approvepage> createState() => _ApprovepageState();
}

class _ApprovepageState extends State<Approvepage> {
  List<dynamic> _pendingRequests = [];
  bool _loading = true;

  // ✅ ถ้าใช้ Emulator ให้ใช้ 10.0.2.2
  // ถ้าใช้มือถือจริง (Wi-Fi เดียวกับ backend) ให้เปลี่ยนเป็น IP เครื่อง เช่น "http://192.168.1.7:3005"
  final String baseUrl = "http://10.0.2.2:3005";

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  // ✅ โหลดคำขอที่รออนุมัติ
  Future<void> _fetchPendingRequests() async {
    try {
      final response = await session.get(
        Uri.parse('$baseUrl/pending-requests'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _pendingRequests = json.decode(response.body);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print("❌ Error loading pending requests: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _updateRequest(int requestId, String status) async {
    print("📤 Sending to API: request_id=$requestId, booking_status=$status");

    try {
      final response = await session.post(
        Uri.parse('$baseUrl/update-requests'),
        body: jsonEncode([
          {"request_id": requestId, "status": status},
        ]),

        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        // ✅ ลบรายการจาก list ทันที
        setState(() {
          _pendingRequests.removeWhere((req) {
            print('Removing ID: ${req['request_id']} == $requestId');
            return req['request_id'] == requestId;
          });
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      print("❌ Error updating request: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: const Text(
          "Approver",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFF9F7F5),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? RefreshIndicator(
                  onRefresh: _fetchPendingRequests,
                  child: ListView(
                    children: const [
                      SizedBox(height: 300),
                      Center(
                        child: Text(
                          "No pending requests",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPendingRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final req = _pendingRequests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req['username'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                req['room_name'] ?? '',
                                style: const TextStyle(fontSize: 18),
                              ),
                              Text(
                                req['booking_date'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                req['booking_time'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Reason: ${req['reason'] ?? ''}",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _updateRequest(
                                        req['request_id'], "approve"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text(
                                      "Approve",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _updateRequest(
                                        req['request_id'], "reject"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      "Reject",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
