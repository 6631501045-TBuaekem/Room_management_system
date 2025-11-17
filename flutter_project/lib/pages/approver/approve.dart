import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utills/http_cilent.dart';

class Approvepage extends StatefulWidget {
  const Approvepage({super.key});

  @override
  State<Approvepage> createState() => _ApprovepageState();
}

class _ApprovepageState extends State<Approvepage> {
  List<dynamic> requests = [];
  bool loading = true;
  final baseUrl = "http://10.0.2.2:3005";

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    setState(() => loading = true);
    try {
      final res = await HttpClient.get(Uri.parse('$baseUrl/pending-requests'));
      if (res.statusCode == 200) requests = jsonDecode(res.body);
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> updateRequest(int id, String status, {String? reason}) async {
    try {
      await HttpClient.post(Uri.parse('$baseUrl/update-requests'),
          body: jsonEncode([
            {"request_id": id, "status": status, if (reason != null) "reject_reason": reason}
          ]));
      setState(() => requests.removeWhere((r) => r['request_id'] == id));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<bool?> showConfirmDialog(String title, {Widget? content}) {
    return showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: content,
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Confirm", style: TextStyle(color: Colors.white))),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: const Text("Approver",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF9F7F5),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: loadRequests,
        child: requests.isEmpty
            ? ListView(children: const [SizedBox(height: 300), Center(child: Text("No pending requests"))])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (_, i) {
                  final r = requests[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['username'] ?? '-', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(r['room_name'] ?? '', style: const TextStyle(fontSize: 18)),
                          Text(r['booking_date'] ?? '', style: const TextStyle(fontSize: 16)),
                          Text(r['booking_time'] ?? '', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text("Reason: ${r['reason'] ?? ''}", style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text("Approve", style: TextStyle(color: Colors.white)),
                                  onPressed: () async {
                                    if (await showConfirmDialog("Confirm Approve") == true) {
                                      updateRequest(r['request_id'], "approve");
                                    }
                                  }),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text("Reject", style: TextStyle(color: Colors.white)),
                                  onPressed: () async {
                                    final reasonCtrl = TextEditingController();
                                    if (await showConfirmDialog("Reject Request",
                                            content: TextField(
                                                controller: reasonCtrl,
                                                maxLines: 3,
                                                decoration: const InputDecoration(
                                                    labelText: "Reason for rejection",
                                                    hintText: "Enter reason...",
                                                    border: OutlineInputBorder()))) ==
                                        true) {
                                      if (reasonCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(content: Text("Please enter a reason")));
                                        return;
                                      }
                                      updateRequest(r['request_id'], "reject", reason: reasonCtrl.text.trim());
                                    }
                                  }),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }),
      ),
    );
  }
}