import 'package:flutter/material.dart';
import '../../utills/session_cilent.dart';
import 'dart:convert';

final session = SessionHttpClient();

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

  Future<void> fetchRooms() async {
    try {
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final url = Uri.parse(
        'http://10.0.2.2:3005/rooms/request/info?date=$today',
      );
      final response = await session.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          rooms = data;
          filteredRooms = data;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchStatus() async {
    try {
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final url = Uri.parse(
        'http://10.0.2.2:3005/rooms/check/info?date=$today',
      );
      final response = await session.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          // store full booking list for room/time comparison
          getRoomstatus = data['bookings'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      }
    } catch (e) {
      debugPrint('Error fetching room status: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void searchRoom(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredRooms = rooms;
      } else {
        filteredRooms = rooms.where((room) {
          final name = room['room_name']?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> bookingRoom(int roomId, String timeSlot, String reason) async {
    try {
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final mappedSlot = mapTimeSlot(timeSlot);
      if (mappedSlot.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid time slot mapping.')),
        );
        return;
      }

      final body = {
        "room_id": roomId.toString(),
        "date": today,
        "timeSlot": mappedSlot,
        "reason": reason,
      };
      final url = Uri.parse('http://10.0.2.2:3005/rooms/request');
      final response = await session.post(url, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Booking successful")),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? response.body)),
        );
      }
      fetchRooms();
      fetchStatus();
    } catch (e) {
      debugPrint('Error booking room: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void showBookingDialog(int roomId, String roomName, String timeSlot) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text('Request Room'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Time Slot: $timeSlot', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 20),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 165, 34, 24),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason.')),
                  );
                  return;
                }
                Navigator.pop(context);
                bookingRoom(roomId, timeSlot, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 53, 151, 56),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
          ],
        );
      },
    );
  }

  Widget buildSingleRoom(
    int roomId,
    String title,
    String description,
    Map<String, dynamic> timeSlots,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5F5),
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(description, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
        ...timeSlots.entries.map((slot) {
        // find matching booking by status only (ignore room/time)
        final booking = getRoomstatus.firstWhere(
          (b) => b['booking_status'] != null,
          orElse: () => null as dynamic,
        );

        final status = booking?['booking_status'] ?? 'free';
        final isEnabled = status == 'free' || status == 'reject';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(slot.key, style: const TextStyle(fontSize: 17)),
            ElevatedButton(
              onPressed: isEnabled
                  ? () => showBookingDialog(roomId, title, slot.key)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled
                    ? const Color.fromARGB(255, 77, 156, 80) // green
                    : Colors.grey, // grey
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              ),
              child: const Text(
                'Request',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        );
      }),

        ],
      ),
    );
  }

  Widget buildRoomPage(List<dynamic> pair) {
    return SingleChildScrollView(
      child: Column(
        children: pair.map((room) {
          final timeSlots = Map<String, dynamic>.from(room['timeSlots']);
          return buildSingleRoom(
            room['room_id'],
            room['room_name'],
            room['room_description'],
            timeSlots,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 229, 229),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rooms.isEmpty
              ? const Center(child: Text('No rooms found.'))
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5F5),
                            border: Border.all(color: Colors.black, width: 1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search),
                              const SizedBox(width: 5),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search room',
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                  ),
                                  controller: controllerSearch,
                                  onChanged: searchRoom,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed: () {
                                  setState(() {
                                    controllerSearch.clear();
                                    searchRoom('');
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await fetchRooms();
                            await fetchStatus();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: (filteredRooms.length / 2).ceil(),
                            itemBuilder: (context, index) {
                              final start = index * 2;
                              final end = (start + 2 > filteredRooms.length)
                                  ? filteredRooms.length
                                  : start + 2;
                              final pair = filteredRooms.sublist(start, end);
                              return buildRoomPage(pair);
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
