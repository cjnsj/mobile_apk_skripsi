import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Query ke node 'parking_logs', diurutkan berdasarkan timestamp
  final Query _logQuery = FirebaseDatabase.instance.ref().child('parking_logs').orderByChild('timestamp');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Kunjungan"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: FirebaseAnimatedList(
          query: _logQuery,
          // Sortir: Data terbaru (timestamp besar) di paling atas
          sort: (DataSnapshot a, DataSnapshot b) {
            // PERBAIKAN: Handle jika data timestamp null atau error
            int timeA = 0;
            int timeB = 0;
            try {
              timeA = int.parse(a.child('timestamp').value.toString());
            } catch (_) {}
            try {
              timeB = int.parse(b.child('timestamp').value.toString());
            } catch (_) {}

            return timeB.compareTo(timeA);
          },
          defaultChild: const Center(child: CircularProgressIndicator()),
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, snapshot, animation, index) {
            final json = snapshot.value as Map<dynamic, dynamic>;

            final String floor = json['floor'] ?? 'Unknown';
            final String type = json['type'] ?? '-';

            // PERBAIKAN SAFETY CHECK (Agar tidak crash merah)
            int timestamp;
            if (json['timestamp'] is int) {
              timestamp = json['timestamp'];
            } else {
              // Jika data error (String/Null), gunakan waktu sekarang agar app tetap jalan
              timestamp = DateTime.now().millisecondsSinceEpoch;
            }

            // Format Tanggal
            final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final String dateStr = DateFormat('dd MMM yyyy').format(date);
            final String timeStr = DateFormat('HH:mm').format(date);

            // Tentukan Warna & Icon berdasarkan Tipe Mobil
            bool isHighClearance = type.contains("Tinggi");
            Color iconColor = isHighClearance ? Colors.orange : Colors.green;
            IconData iconData = isHighClearance ? Icons.directions_bus : Icons.directions_car;

            return SizeTransition(
              sizeFactor: animation,
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    // Icon Lingkaran Kiri (Lantai)
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: floor == "Lantai 1" ? Colors.blue.shade100 : Colors.purple.shade100,
                      child: Text(
                        floor == "Lantai 1" ? "L1" : "L2",
                        style: TextStyle(
                          color: floor == "Lantai 1" ? Colors.blue.shade800 : Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Info Utama (Tipe Mobil)
                    title: Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),

                    // Info Tambahan (Waktu)
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("$dateStr  |  $timeStr", style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ),

                    // Icon Kanan (Jenis Visual)
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconData, color: iconColor),
                        Text(
                          isHighClearance ? "SUV/MPV" : "Sedan",
                          style: TextStyle(fontSize: 10, color: iconColor),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}