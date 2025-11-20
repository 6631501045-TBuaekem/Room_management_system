import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utills/http_cilent.dart';  // USE JWT CLIENT

final String baseUrl = "http://10.0.2.2:3005";


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

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final String fullDateTime =
        "${json['booking_date']} ${json['booking_time']}";
    final String status = json['status'];
    final String formattedStatus =
        status[0].toUpperCase() + status.substring(1).toLowerCase();

    final String? approver = (json['approver_name'] != "-" &&
            json['approver_name'] != null)
        ? json['approver_name']
        : null;

    return HistoryEntry(
      json['room'],
      json['booking_timeslot'],
      fullDateTime,
      formattedStatus,
      json['booker_name'],
      approvedBy: approver,
    );
  }
}

// =====================================================
// WIDGET
// =====================================================
class Historypage extends StatefulWidget {
  final String currentRoleCode; // "0", "1", "2"

  const Historypage({super.key, this.currentRoleCode = "0"});

  @override
  State<Historypage> createState() => _HistorypageState();
}

class _HistorypageState extends State<Historypage> {
  List<HistoryEntry> _historyData = [];
  bool _isLoading = true;
  String? _error;
  String? _currentRole;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // โหลดโปรไฟล์ก่อน แล้วโหลด history
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ok = await _fetchProfileRole();
    if (ok) await _fetchHistoryData();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // เอา role จาก profile
  Future<bool> _fetchProfileRole() async {
    try {
      final http.Response res =
          await HttpClient.get(Uri.parse("$baseUrl/profile"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _currentRole = data['role']?.toString();
        return _currentRole != null;
      } else {
        _error = "Failed to load profile (${res.statusCode})";
        return false;
      }
    } catch (e) {
      _error = "Connection error (profile): $e";
      return false;
    }
  }

  // เอาประวัติ
  Future<void> _fetchHistoryData() async {
    try {
      final http.Response res =
          await HttpClient.get(Uri.parse("$baseUrl/history/info"));

      if (res.statusCode == 200) {
        final List raw = json.decode(res.body);
        _historyData = raw
            .map((e) => HistoryEntry.fromJson(e))
            .where((entry) => entry.status != "Pending")
            .toList();
      } else {
        _error = "Failed to load history (${res.statusCode})";
      }
    } catch (e) {
      _error = "Connection error (history): $e";
    }
  }


  Widget _buildHistoryItem(HistoryEntry entry) {
    final String role = _currentRole ?? "0";
    final bool isStudent = role == "0";
    final bool isStaff = role == "1";
    final bool isRejected = entry.status == "Reject";

    final statusColor = isRejected ? Colors.red : Colors.green;

final String thirdHeader = isStudent
    ? (isRejected ? "Rejected by" : "Approve by")
    : "User";

final String thirdData = isStudent
    ? (entry.approvedBy ?? "-")
    : entry.user;

    final bool showApprovedBelow = isStaff && entry.approvedBy != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Name + Time Slot
            Center(
              child: Column(
                children: [
                  Text(entry.location,
                      style:
                          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(entry.timeRange,
                      style: const TextStyle(fontSize: 18, color: Colors.black87)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text("Date/Time",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Expanded(
                  flex: 4,
                  child: Text("Status",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(thirdHeader,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Data Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(entry.dateTime,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17)),
                ),
                Expanded(
                  flex: 4,
                  child: Text(entry.status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: statusColor)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(thirdData,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17)),
                ),
              ],
            ),

            if (showApprovedBelow) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRejected ? "Rejected by:" : "Approved by:",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  Text(entry.approvedBy!,
                    style: const TextStyle(fontSize: 18)), 
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

// ฟังก์ชันหลัก
  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text("Error: $_error"));
    } else if (_historyData.isEmpty) {
      body = const Center(child: Text("No history found."));
    } else {
      body = ListView.builder(
        itemCount: _historyData.length,
        itemBuilder: (_, i) => _buildHistoryItem(_historyData[i]),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6F4),
      appBar: AppBar(
        title: const Text("History",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFFBF6F4),
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: body,
      ),
    );
  }
}
