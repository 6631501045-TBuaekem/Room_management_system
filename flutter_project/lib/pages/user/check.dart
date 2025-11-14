import 'package:flutter/material.dart';
import '../../utills/http_cilent.dart';  
import 'dart:convert';

class Checkroompage extends StatefulWidget {
  const Checkroompage({super.key});

  @override
  State<Checkroompage> createState() => __CheckroomState();
}

class __CheckroomState extends State<Checkroompage> {
  List<dynamic> rooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  // Fetch user's booking
  Future<void> fetchRooms() async {
    try {
      final response = await HttpClient.get(
        Uri.parse('http://10.0.2.2:3005/rooms/check/info'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // handle both API formats
        final List<dynamic> bookingList =
            (data is List) ? data : (data['bookings'] ?? []);

        setState(() {
          rooms = bookingList;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching rooms: $e");
      setState(() => isLoading = false);
    }
  }


  // room card
  Widget buildSingleRoom(
    int roomId,
    String title,
    String description,
    String timeSlots,
    String status,
    String bookingDate,
    String reason,
    String? rejectReason
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
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text(description, style: const TextStyle(fontSize: 18)),

          const SizedBox(height: 10),
          Text("Booking Date: $bookingDate",
              style: const TextStyle(fontSize: 17)),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(timeSlots, style: const TextStyle(fontSize: 17)),
              Text(
                "${status[0].toUpperCase()}${status.substring(1)}",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: status.toLowerCase() == 'approve'
                      ? Colors.green
                      : status.toLowerCase() == 'pending'
                          ? Colors.orange
                          : status.toLowerCase() == 'reject'
                              ? Colors.red
                              : Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              const Text(
                "Your reason: ",
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(reason, style: const TextStyle(fontSize: 17)),
            ],
          ),

          if (status.toLowerCase() == 'reject')
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notification_important,
                  color: Colors.red,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: (rejectReason == null || rejectReason == "null")
                              ? ""
                              : rejectReason,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 91, 22, 148), // color for rejectReason
                          ),
                        ),
                        TextSpan(
                          text: (rejectReason == null || rejectReason == "null")
                              ? "Please make a reservation again"
                              : " , Please make a reservation again",
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color.fromARGB(255, 56, 114, 190), // color for the remaining text
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // build room
  Widget buildRoomPage(List<dynamic> pair) {
    return SingleChildScrollView(
      child: Column(
        children: pair.map((room) {
          return buildSingleRoom(
            room['request_id'],
            room['room_name'],
            room['room_description'],
            room['booking_time'],
            room['booking_status'],
            room['booking_date'],
            room['reason'],
            room['reject_reason']
          );
        }).toList(),
      ),
    );
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 229, 229),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())

          : rooms.isEmpty
              ? const Center(child: Text("No rooms found."))

              : SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: Colors.grey, width: 1),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            "Your booking room",
                            style: TextStyle(fontSize: 25),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: fetchRooms,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: (rooms.length / 2).ceil(),
                            itemBuilder: (_, i) {
                              final start = i * 2;
                              final end = (start + 2 > rooms.length)
                                  ? rooms.length
                                  : start + 2;

                              final pair =
                                  rooms.sublist(start, end);

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
