import 'package:flutter/material.dart';
import '../../utills/http_cilent.dart';  
import 'dart:convert';

class Requestroompage extends StatefulWidget {
  const Requestroompage({super.key});

  @override
  State<Requestroompage> createState() => __RequestroomState();
}

class __RequestroomState extends State<Requestroompage> {
  final TextEditingController controllerSearch = TextEditingController();

  List<dynamic> rooms = [];
  List<dynamic> getRoomstatus = [];
  List<dynamic> filteredRooms = [];
  bool isLoading = true;

  String mapTimeSlot(String slot) {
    switch (slot) {
      case "08.00 - 10.00":
        return "8";
      case "10.00 - 12.00":
        return "10";
      case "13.00 - 15.00":
        return "13";
      case "15.00 - 17.00":
        return "15";
      default:
        return "";
    }
  }

  @override
  void initState() {
    super.initState();
    fetchRooms();
    fetchStatus();
  }

  // Fetch available rooms
  Future<void> fetchRooms() async {
    try {
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final response = await HttpClient.get(
        Uri.parse("http://10.0.2.2:3005/rooms/request/info?date=$today"),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          rooms = data;
          filteredRooms = data;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.body)));
      }
    } catch (e) {
      debugPrint("❌ Error fetching rooms: $e");
      setState(() => isLoading = false);
    }
  }

  // Fetch current user's booked room status
  Future<void> fetchStatus() async {
    try {
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final response = await HttpClient.get(
        Uri.parse("http://10.0.2.2:3005/rooms/check/info?date=$today"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          getRoomstatus = data["bookings"] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.body)));
      }
    } catch (e) {
      debugPrint("❌ Error fetching room status: $e");
    }
  }

  // Filter search
  void searchRoom(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredRooms = rooms;
      } else {
        filteredRooms = rooms.where((room) {
          final name = (room["room_name"] ?? "").toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // Send booking request
  Future<void> bookingRoom(int roomId, String timeSlot, String reason) async {
    try {
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final mappedSlot = mapTimeSlot(timeSlot);

      if (mappedSlot.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid time slot mapping.")),
        );
        return;
      }

      final body = {
        "room_id": roomId.toString(),
        "date": today,
        "timeSlot": mappedSlot,
        "reason": reason,
      };

      final response = await HttpClient.post(
        Uri.parse("http://10.0.2.2:3005/rooms/request"),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Booking successful")),
      );

      fetchRooms();
      fetchStatus();
    } catch (e) {
      debugPrint("❌ Error booking room: $e");
    }
  }

  // Booking dialog
  void showBookingDialog(int roomId, String roomName, String timeSlot) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Request Room"),
        content: SizedBox(
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Time Slot: $timeSlot", style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter reason...",
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("Enter reason")));
                return;
              }
              Navigator.pop(context);
              bookingRoom(roomId, timeSlot, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Room card
  Widget buildSingleRoom(
      int roomId, String title, String description, Map<String, dynamic> timeSlots) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5F5),
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(description, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),

          ...timeSlots.entries.map((slot) {
            bool isEnabled = true;

            // Check user's booking status
            for (var b in getRoomstatus) {
              if (b["booking_status"] == "pending" ||
                  b["booking_status"] == "approve") {
                isEnabled = false;
                break;
              }
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(slot.key, style: const TextStyle(fontSize: 17)),
                ElevatedButton(
                  onPressed:
                      isEnabled ? () => showBookingDialog(roomId, title, slot.key) : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: isEnabled ? Colors.green : Colors.grey),
                  child: const Text("Request", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget buildRoomPage(List<dynamic> pair) {
    return Column(
      children: pair.map((room) {
        return buildSingleRoom(
          room["room_id"],
          room["room_name"],
          room["room_description"],
          Map<String, dynamic>.from(room["timeSlots"]),
        );
      }).toList(),
    );
  }


  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 229, 229),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())

          : filteredRooms.isEmpty
              ? const Center(child: Text("No rooms found."))

              : SafeArea(
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5F5),
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search),
                              const SizedBox(width: 5),
                              Expanded(
                                child: TextField(
                                  controller: controllerSearch,
                                  decoration: const InputDecoration(
                                    hintText: "Search room",
                                    border: InputBorder.none,
                                  ),
                                  onChanged: searchRoom,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  controllerSearch.clear();
                                  searchRoom("");
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Room List
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await fetchRooms();
                            await fetchStatus();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: (filteredRooms.length / 2).ceil(),
                            itemBuilder: (_, i) {
                              final start = i * 2;
                              final end = (start + 2 > filteredRooms.length)
                                  ? filteredRooms.length
                                  : start + 2;
                              return buildRoomPage(
                                  filteredRooms.sublist(start, end));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
