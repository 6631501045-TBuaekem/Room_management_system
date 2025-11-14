import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utills/http_cilent.dart';  // <-- FIXED import

class Approvepage extends StatefulWidget {
  const Approvepage({super.key});

  @override
  State<Approvepage> createState() => _ApprovepageState();
}

class _ApprovepageState extends State<Approvepage> {
  List<dynamic> _pendingRequests = [];
  bool _loading = true;

  final String baseUrl = "http://10.0.2.2:3005"; // Emulator URL

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  
  // Load pending requests
  Future<void> _fetchPendingRequests() async {
    setState(() => _loading = true);

    try {
      final response =
          await HttpClient.get(Uri.parse('$baseUrl/pending-requests'));

      if (response.statusCode == 200) {
        setState(() {
          _pendingRequests = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        print("❌ Failed to load pending requests (${response.statusCode})");
      }
    } catch (e) {
      print("❌ Error: $e");
      setState(() => _loading = false);
    }
  }

  
  // Approve or Reject request
  Future<void> _updateRequest(int requestId, String status, {String? reason}) async {
    print("📤 Sending update: request_id=$requestId, status=$status");

    try {
      final response = await HttpClient.post(
        Uri.parse('$baseUrl/update-requests'),
        body: jsonEncode([
          {"request_id": requestId, "status": status,
            if (reason != null) "reject_reason": reason
          },
        ]),
      );

      if (response.statusCode == 200) {
        // Remove instantly from UI
        setState(() {
          _pendingRequests.removeWhere((req) => req['request_id'] == requestId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (e) {
      print("❌ Update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

// UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: const Text(
          "Approver",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF9F7F5),
        elevation: 0,
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())

          // No pending requests
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

              // Pending requests list
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
                              Text(req['room_name'] ?? '',
                                  style: const TextStyle(fontSize: 18)),
                              Text(req['booking_date'] ?? '',
                                  style: const TextStyle(fontSize: 16)),
                              Text(req['booking_time'] ?? '',
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              Text(
                                "Reason: ${req['reason'] ?? ''}",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),

                              // Approve / Reject Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                    ElevatedButton(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Confirm Approve"),
                                          content: const Text("Approve this request?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text("No"),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text("Yes"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        _updateRequest(req['request_id'], "approve");
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text(
                                      "Approve",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),

                                  ElevatedButton(
                                  onPressed: () async {
                                    final TextEditingController reasonController = TextEditingController();

                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Reject Request"),
                                        content: TextField(
                                          controller: reasonController,
                                          decoration: const InputDecoration(
                                            labelText: "Reason for rejection",
                                            hintText: "Enter reason...",
                                            border: OutlineInputBorder(),
                                          ),
                                          maxLines: 3,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("No"),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              if (reasonController.text.trim().isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Please enter a reason")),
                                                );
                                                return;
                                              }
                                              Navigator.pop(context, true);
                                            },
                                            child: const Text("Yes"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      _updateRequest(
                                        req['request_id'],
                                        "reject",
                                        reason: reasonController.text.trim(),
                                      );
                                    }
                                  },

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
