import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utills/session_cilent.dart';
import 'dart:convert';

final session = SessionHttpClient();

class Manageroompage extends StatefulWidget {
  const Manageroompage({super.key});

  @override
  State<Manageroompage> createState() => _ManageroompageState();
}

class _ManageroompageState extends State<Manageroompage> {
  final TextEditingController searchCtrl = TextEditingController();
  List<dynamic> rooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  // Fetch all rooms (Free or Disable only)
  Future<void> fetchRooms() async {
    try {
      final url = Uri.parse('http://10.0.2.2:3005/rooms/manage/info');
      final response = await session.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          rooms = data;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.body)));
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      setState(() => isLoading = false);
    }
  }

  // Add room
  Future<void> addRoom(String name, String desc) async {
    try {
      final url = Uri.parse('http://10.0.2.2:3005/rooms/manage/add');
      final body = {"room_name": name, "room_description": desc};
      final response = await session.post(url, body: jsonEncode(body));
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data['message'] ?? response.body)));
      await fetchRooms();
    } catch (e) {
      debugPrint('Error adding room: $e');
    }
  }

  // Edit room
  Future<void> editRoom(int id, String name, String desc) async {
    try {
      final url = Uri.parse('http://10.0.2.2:3005/rooms/manage/edit');
      final body = {"room_id": id, "room_name": name, "room_description": desc};
      final response = await session.put(url, body: jsonEncode(body));
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data['message'] ?? response.body)));
      await fetchRooms();
    } catch (e) {
      debugPrint('Error editing room: $e');
    }
  }

  // Enable / Disable room
  Future<void> toggleRoomStatus(int roomId, bool enabled) async {
    try {
      final url = Uri.parse('http://10.0.2.2:3005/rooms/manage/enaanddis');
      final action = enabled ? "enable" : "disable";
      final body = {"room_id": roomId, "action": action};
      final response = await session.put(url, body: jsonEncode(body));
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data['message'] ?? response.body)));
      await fetchRooms();
    } catch (e) {
      debugPrint('Error toggling room: $e');
    }
  }

  void openAddRoomDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Room Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
              Navigator.pop(context);
              await addRoom(nameCtrl.text, descCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void openEditDialog(Map<String, dynamic> room) {
    final nameCtrl = TextEditingController(text: room['room_name']);
    final descCtrl = TextEditingController(text: room['room_description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Room Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
              Navigator.pop(context);
              await editRoom(room['room_id'], nameCtrl.text, descCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = rooms.where((r) {
      final name = (r['room_name'] ?? '').toString().toLowerCase();
      final query = searchCtrl.text.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add / Edit Room', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F7F7),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search room',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: openAddRoomDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: const Text('Add Room', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchRooms,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredRooms.length,
                      itemBuilder: (context, index) {
                        final r = filteredRooms[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      r['room_name'] ?? 'Unnamed Room',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Text('Free', style: TextStyle(fontSize: 15)),
                                        CupertinoSwitch(
                                          value: r['timeSlots']
                                                  ?.values
                                                  ?.any((s) => s == "Free") ??
                                              false,
                                          onChanged: (v) async {
                                            await toggleRoomStatus(r['room_id'], v);
                                          },
                                          activeColor: Colors.green,
                                        ),
                                        const Text('Disable',
                                            style: TextStyle(fontSize: 15)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r['room_description'] ?? '',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => openEditDialog(r),
                                    child: const Text('Edit Room',
                                        style: TextStyle(color: Color(0xFF9747FF))),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: (r['timeSlots'] as Map<String, dynamic>)
                                      .entries
                                      .map<Widget>((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(entry.key,
                                              style: const TextStyle(fontSize: 13)),
                                          Text(
                                            entry.value,
                                            style: TextStyle(
                                              color: entry.value == "Free"
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
