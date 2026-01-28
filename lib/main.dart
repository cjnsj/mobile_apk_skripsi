import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart'; // PENTING: Import ini harus ada

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyDUqAFG-YdqaZplNru3Ba_HqtQF2UtL-54",
      databaseURL: "https://skripsi-742b2-default-rtdb.firebaseio.com",
      projectId: "skripsi-742b2",
      storageBucket: "skripsi-742b2.appspot.com",
      messagingSenderId: "YOUR_SENDER_ID",
      appId: "YOUR_APP_ID",
    ),
  );
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
      home: DashboardScreen(), // GANTI: DashboardPage() → DashboardScreen()
    );
  }
}
