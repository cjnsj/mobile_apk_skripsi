import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // --- STATE VARIABLES ---
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  String _selectedFloor = 'Semua';
  String _selectedType = 'Semua';

  List<Map<dynamic, dynamic>> _filteredLogs = [];
  bool _isLoading = false;

  // Variabel untuk Ringkasan
  int _countL1 = 0;
  int _countL2 = 0;

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  Future<void> _applyFilter() async {
    setState(() => _isLoading = true);

    try {
      final int startTimestamp = DateTime(
              _selectedDateRange.start.year,
              _selectedDateRange.start.month,
              _selectedDateRange.start.day,
              0,
              0,
              0)
          .millisecondsSinceEpoch;

      final int endTimestamp = DateTime(
              _selectedDateRange.end.year,
              _selectedDateRange.end.month,
              _selectedDateRange.end.day,
              23,
              59,
              59)
          .millisecondsSinceEpoch;

      final ref = FirebaseDatabase.instance.ref().child('parking_logs');
      final snapshot = await ref
          .orderByChild('timestamp')
          .startAt(startTimestamp)
          .endAt(endTimestamp)
          .once();

      List<Map<dynamic, dynamic>> tempList = [];
      int tempL1 = 0;
      int tempL2 = 0;

      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          final log = Map<dynamic, dynamic>.from(value);
          final String floor = log['floor'] ?? '';
          final String type = log['type'] ?? '';

          // Logic Filter
          bool floorMatch = true;
          if (_selectedFloor == 'Lantai 1') floorMatch = floor == 'Lantai 1';
          if (_selectedFloor == 'Lantai 2') floorMatch = floor != 'Lantai 1';

          bool typeMatch = true;
          bool isHigh = type.contains('Tinggi');
          if (_selectedType == 'SUV/MPV') typeMatch = isHigh;
          if (_selectedType == 'Sedan') typeMatch = !isHigh;

          if (floorMatch && typeMatch) {
            tempList.add(log);
            // Hitung Ringkasan
            if (floor == 'Lantai 1')
              tempL1++;
            else
              tempL2++; // Asumsi selain L1 adalah L2
          }
        });
      }

      // Sorting: Terbaru paling atas
      tempList.sort((a, b) {
        int timeA = a['timestamp'] ?? 0;
        int timeB = b['timestamp'] ?? 0;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _filteredLogs = tempList;
        _countL1 = tempL1;
        _countL2 = tempL2;
      });
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat data: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateText =
        "${DateFormat('dd MMM').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("Laporan Parkir",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // SARAN TAMBAHAN: Tombol Export (UI Saja dulu)
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: "Cetak Laporan",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Fitur Cetak PDF akan segera hadir!")),
              );
            },
          )
        ],
      ),
      // PERUBAHAN UTAMA: Menggunakan Column agar list bisa di-scroll terpisah dari filter
      body: Column(
        children: [
          // --- BAGIAN 1: FILTER (Tetap di atas, tidak ikut scroll) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                // Pilih Tanggal
                InkWell(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month,
                                color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(dateText,
                                style: GoogleFonts.poppins(fontSize: 14)),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Row Dropdown & Tombol
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedFloor,
                        decoration: InputDecoration(
                          labelText: "Lantai",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Semua', child: Text("Semua")),
                          DropdownMenuItem(
                              value: 'Lantai 1', child: Text("Lt 1")),
                          DropdownMenuItem(
                              value: 'Lantai 2', child: Text("Lt 2")),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedFloor = val!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: "Tipe",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Semua', child: Text("Semua")),
                          DropdownMenuItem(
                              value: 'SUV/MPV', child: Text("SUV")),
                          DropdownMenuItem(
                              value: 'Sedan', child: Text("Sedan")),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedType = val!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Search Kecil
                    InkWell(
                      onTap: _applyFilter,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.search,
                            color: Colors.white, size: 24),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // --- BAGIAN 2: RINGKASAN HASIL ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Hasil: ${_filteredLogs.length} Data",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                // Detail Ringkasan
                if (_filteredLogs.isNotEmpty)
                  Row(
                    children: [
                      _buildBadge("Lt 1: $_countL1", Colors.blue),
                      const SizedBox(width: 8),
                      _buildBadge("Lt 2: $_countL2", Colors.purple),
                    ],
                  )
              ],
            ),
          ),

          // --- BAGIAN 3: LIST DATA (SCROLLABLE) ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text("Tidak ada data",
                                style: GoogleFonts.poppins(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];

                          final String floor = log['floor'] ?? 'Unknown';
                          final String type = log['type'] ?? '-';
                          final int timestamp = log['timestamp'] is int
                              ? log['timestamp']
                              : DateTime.now().millisecondsSinceEpoch;

                          final DateTime date =
                              DateTime.fromMillisecondsSinceEpoch(timestamp);
                          final String dateStr =
                              DateFormat('dd MMM').format(date);
                          final String timeStr =
                              DateFormat('HH:mm').format(date);

                          bool isHighClearance = type.contains("Tinggi");
                          bool isFloor1 = floor == "Lantai 1";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.grey.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2))
                              ],
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                // Tanggal & Jam
                                Column(
                                  children: [
                                    Text(dateStr,
                                        style: GoogleFonts.poppins(
                                            fontSize: 10, color: Colors.grey)),
                                    Text(timeStr,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                                Container(
                                    height: 35,
                                    width: 1,
                                    color: Colors.grey.shade200,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16)),

                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isHighClearance
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isHighClearance
                                        ? Icons.directions_bus
                                        : Icons.directions_car,
                                    color: isHighClearance
                                        ? Colors.orange
                                        : Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Detail Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(type,
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Row(
                                        children: [
                                          Icon(Icons.layers_outlined,
                                              size: 14,
                                              color: isFloor1
                                                  ? Colors.blue
                                                  : Colors.purple),
                                          const SizedBox(width: 4),
                                          Text(
                                            isFloor1 ? "Lantai 1" : "Lantai 2",
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Widget Kecil untuk Badge L1/L2
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
