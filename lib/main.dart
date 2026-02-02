import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mencegah error "Duplicate App" saat Hot Restart di HP
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDUqAFG-YdqaZplNru3Ba_HqtQF2UtL-54",
        databaseURL: "https://skripsi-742b2-default-rtdb.firebaseio.com",
        projectId: "skripsi-742b2",
        storageBucket: "skripsi-742b2.firebasestorage.app", 
        messagingSenderId: "960197562235", // SUDAH DIPERBAIKI
        appId: "1:960197562235:android:62335753a3c95bcf4637de", // SUDAH DIPERBAIKI
      ),
    );
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: DashboardScreen(),
    );
  }
}