import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../pages/loginout/login.dart';

const String url = '10.0.2.2:3005'; // <-- updated for your server

void popDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(title: Text(title), content: Text(message));
    },
  );
}

void logout(context) async {
  const storage = FlutterSecureStorage();
  await storage.delete(key: 'token');

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const Loginpage()),
    (route) => false,
  );
}

void confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sure to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => logout(context),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
}

Future<String> getToken(context) async {
  const storage = FlutterSecureStorage();
  String? token = await storage.read(key: 'token');

  if (token == null) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Loginpage()),
    );
    return '';
  }

  return token;
}

// === Extract JWT payload ===
Future<Map<String, dynamic>> getPayload(context) async {
  String token = await getToken(context);
  return JwtDecoder.decode(token);
}
