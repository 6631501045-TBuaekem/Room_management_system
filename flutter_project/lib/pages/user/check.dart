import 'package:flutter/material.dart';
import '../../utills/session_cilent.dart';
import 'dart:convert';

final session = SessionHttpClient();

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

  Future<void> fetchRooms() async {
    try {
      final url = Uri.parse('http://10.0.2.2:3005/rooms/check/info');
      final response = await session.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // handle both array or object with "bookings"
        final List<dynamic> bookingList = data is List
            ? data
            : (data['bookings'] ?? []);
        setState(() {
          rooms = bookingList;
          isLoading = false;
        });
      } else {
        String message = response.body;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildSingleRoom(
    int roomId,
    String title,
    String description,
    String timeSlots,
    String status,
    String bookingDate,
    String reason,
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
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(description, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsetsGeometry.symmetric(vertical: 16),
            child: Text(
              'Booking Date:  $bookingDate',
              style: TextStyle(fontSize: 17),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 20,
              bottom: 20,
              left: 15,
              right: 15,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeSlots, style: TextStyle(fontSize: 17)),
                Text(
                  '${status[0].toUpperCase()}${status.substring(1)}',
                  style: TextStyle(fontSize: 17),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          Row(
            children: [
              Text(
                'Your reason: ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(reason, style: TextStyle(fontSize: 17)),
            ],
          ),
        ],
      ),
    );
  }

  // each page contains 2 rooms
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
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 241, 229, 229),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rooms.isEmpty
          ? const Center(child: Text('No rooms found.'))
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 20,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color.fromARGB(255, 165, 164, 164),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Your booking room',
                            style: TextStyle(fontSize: 25),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 50),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: fetchRooms,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: (rooms.length / 2).ceil(),
                        itemBuilder: (context, index) {
                          final start = index * 2;
                          final end = (start + 2 > rooms.length)
                              ? rooms.length
                              : start + 2;
                          final pair = rooms.sublist(start, end);
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
