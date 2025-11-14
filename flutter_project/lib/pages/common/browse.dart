import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utills/http_cilent.dart';  // <-- Correct file

class Browseroompage extends StatefulWidget {
  const Browseroompage({super.key});

  @override
  State<Browseroompage> createState() => _BrowseRoomPageState();
}

class _BrowseRoomPageState extends State<Browseroompage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _loading = true;
  List<dynamic> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch room info from API using JWT token
  Future<void> _fetchRooms() async {
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final url = Uri.parse(
          'http://10.0.2.2:3005/rooms/info?date=$dateStr');

      final response = await HttpClient.get(url);

      debugPrint("Status: ${response.statusCode}");
      debugPrint("Body: ${response.body}");

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _rooms = data;
          _loading = false;
        });
      } else if (response.statusCode == 401) {
        debugPrint("❌ Unauthorized — token missing or invalid");
        setState(() => _loading = false);
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _rooms.where((room) {
      final name = (room['room_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchText.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6F4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Browse Room',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() => _searchText = value);
                              },
                              decoration: const InputDecoration(
                                hintText: 'Search room',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.black45),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchText = '');
                              },
                              child: const Icon(Icons.close,
                                  color: Colors.redAccent),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Room List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchRooms,
                        child: filteredRooms.isEmpty
                            ? const Center(
                                child: Text(
                                  'No rooms found',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.black54),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredRooms.length,
                                itemBuilder: (context, index) {
                                  final room = filteredRooms[index];

                                  final timesList = <Map<String, String>>[];

                                  if (room['timeSlots'] != null &&
                                      room['timeSlots'] is Map) {
                                    final map =
                                        room['timeSlots'] as Map<String, dynamic>;

                                    if (map.isEmpty) {
                                      timesList.add({
                                        'time': '-',
                                        'status': 'No slots'
                                      });
                                    } else {
                                      map.forEach((key, value) {
                                        timesList.add({
                                          'time': key,
                                          'status': value.toString(),
                                        });
                                      });
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: _roomCard(
                                      title:
                                          room['room_name'] ?? 'No Name',
                                      subtitle: room['room_description'] ?? '',
                                      times: timesList,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Room card widget
  Widget _roomCard({
    required String title,
    required String subtitle,
    required List<Map<String, String>> times,
  }) {
    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'free':
          return Colors.green;
        case 'reserved':
          return Colors.blue;
        case 'pending':
          return Colors.orange;
        case 'disable':
          return Colors.red;
        default:
          return Colors.black;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Column(
            children: times.map((t) {
              final time = t['time'] ?? '';
              final status = t['status'] ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(time,
                          style: const TextStyle(fontSize: 16)),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: getStatusColor(status)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
