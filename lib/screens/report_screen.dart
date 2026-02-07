import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportScreen extends StatefulWidget {
  // Parameter untuk menerima tanggal dari Dashboard
  final DateTimeRange? initialDateRange;

  const ReportScreen({super.key, this.initialDateRange});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // --- STATE VARIABLES ---
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  String _selectedType = 'Semua';
  List<Map<dynamic, dynamic>> _filteredLogs = [];
  bool _isLoading = false;
  
  // Variabel Info
  String _busiestDayInfo = "-"; 
  int _suvCount = 0;   // Jumlah SUV pada HARI TERAMAI
  int _sedanCount = 0; // Jumlah Sedan pada HARI TERAMAI

  @override
  void initState() {
    super.initState();
    // Jika ada kiriman tanggal dari Dashboard, gunakan itu
    if (widget.initialDateRange != null) {
      _selectedDateRange = widget.initialDateRange!;
    } else {
      _setDefaultDateRangeToCurrentWeek();
    }
    
    _applyFilter();
  }

  void _setDefaultDateRangeToCurrentWeek() {
    DateTime now = DateTime.now();
    DateTime start = now.subtract(Duration(days: now.weekday - 1));
    start = DateTime(start.year, start.month, start.day, 0, 0, 0);

    DateTime end = start.add(const Duration(days: 6));
    end = DateTime(end.year, end.month, end.day, 23, 59, 59);

    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
    });
  }

  // --- LOGIKA MENGHITUNG HARI TERAMAI & PROPORSI KHUSUS ---
  void _calculateStatistics(List<Map<dynamic, dynamic>> logs) {
    if (logs.isEmpty) {
      setState(() {
        _busiestDayInfo = "-";
        _suvCount = 0;
        _sedanCount = 0;
      });
      return;
    }

    // 1. Hitung jumlah per hari
    Map<String, int> dayCounts = {
      'Senin': 0, 'Selasa': 0, 'Rabu': 0, 'Kamis': 0,
      'Jumat': 0, 'Sabtu': 0, 'Minggu': 0
    };

    List<String> dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    for (var log in logs) {
      int ts = (log['timestamp'] is num) ? (log['timestamp'] as num).toInt() : 0;
      if (ts == 0) continue;

      DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
      String dayName = dayNames[date.weekday - 1]; 
      dayCounts[dayName] = (dayCounts[dayName] ?? 0) + 1;
    }

    // 2. Cari Hari Teramai
    var busiestEntry = dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    String busiestDayName = busiestEntry.key;
    int busiestDayTotal = busiestEntry.value;

    if (busiestDayTotal == 0) {
       setState(() {
        _busiestDayInfo = "-";
        _suvCount = 0;
        _sedanCount = 0;
      });
      return;
    }

    // 3. Hitung Proporsi (Sedan vs SUV) HANYA untuk Hari Teramai
    int suvOnBusiest = 0;
    int sedanOnBusiest = 0;

    for (var log in logs) {
      int ts = (log['timestamp'] is num) ? (log['timestamp'] as num).toInt() : 0;
      if (ts == 0) continue;

      DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
      String dayName = dayNames[date.weekday - 1];

      // FILTER PENTING: Hanya hitung jika log ini terjadi di HARI TERAMAI
      if (dayName == busiestDayName) {
        String t = log['type']?.toString().toLowerCase() ?? '';
        if (t.contains('tinggi')) {
          suvOnBusiest++;
        } else {
          sedanOnBusiest++;
        }
      }
    }

    setState(() {
      _busiestDayInfo = "$busiestDayName ($busiestDayTotal Mobil)";
      _suvCount = suvOnBusiest;
      _sedanCount = sedanOnBusiest;
    });
  }

  Future<void> _applyFilter() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final int startTimestamp = DateTime(
        _selectedDateRange.start.year,
        _selectedDateRange.start.month,
        _selectedDateRange.start.day,
        0, 0, 0
      ).millisecondsSinceEpoch;

      final int endTimestamp = DateTime(
        _selectedDateRange.end.year,
        _selectedDateRange.end.month,
        _selectedDateRange.end.day,
        23, 59, 59
      ).millisecondsSinceEpoch;

      final ref = FirebaseDatabase.instance.ref().child('parking_logs');

      final snapshot = await ref
          .orderByChild('timestamp')
          .startAt(startTimestamp)
          .endAt(endTimestamp)
          .once();

      List<Map<dynamic, dynamic>> tempList = [];

      if (snapshot.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.snapshot.value as Map);

        data.forEach((key, value) {
          final log = Map<dynamic, dynamic>.from(value);
          final String type = log['type']?.toString() ?? '';
          final int timestamp = (log['timestamp'] is num)
              ? (log['timestamp'] as num).toInt()
              : 0;

          if (timestamp == 0) return;

          bool typeMatch = true;
          bool isHigh = type.toLowerCase().contains('tinggi');

          if (_selectedType == 'SUV/MPV') typeMatch = isHigh;
          if (_selectedType == 'Sedan') typeMatch = !isHigh;

          if (typeMatch) {
            tempList.add(log);
          }
        });
      }

      tempList.sort((a, b) {
        int timeA = (a['timestamp'] is num) ? (a['timestamp'] as num).toInt() : 0;
        int timeB = (b['timestamp'] is num) ? (b['timestamp'] as num).toInt() : 0;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _filteredLogs = tempList;
        });
        // Panggil fungsi perhitungan statistik baru
        _calculateStatistics(tempList);
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blueAccent,
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _applyFilter();
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _applyFilter,
          )
        ],
      ),
      body: Column(
        children: [
          // --- BAGIAN 1: FILTER ---
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
            child: Column(
              children: [
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
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: "Filter Tipe Kendaraan",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Semua', child: Text("Semua Tipe")),
                    DropdownMenuItem(value: 'SUV/MPV', child: Text("SUV/MPV (Tinggi)")),
                    DropdownMenuItem(value: 'Sedan', child: Text("Sedan (Rendah)")),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedType = val!);
                    _applyFilter();
                  },
                ),
              ],
            ),
          ),

          // --- BAGIAN 2: RINGKASAN TREN ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            padding: const EdgeInsets.all(16),
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text("Hari Teramai",
                          style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(_busiestDayInfo, 
                          style: GoogleFonts.poppins(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.red)), 
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    Column(
                      children: [
                        Text("Total Kunjungan",
                          style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text("${_filteredLogs.length} Mobil", 
                          style: GoogleFonts.poppins(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.blueAccent)),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // VISUAL PROPORSI (KLASIFIKASI DARI HARI TERAMAI)
                Row(
                  children: [
                    Text("$_sedanCount Sedan", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: _sedanCount == 0 ? 0 : _sedanCount,
                              child: Container(height: 8, color: Colors.green),
                            ),
                            Expanded(
                              flex: _suvCount == 0 ? 0 : _suvCount,
                              child: Container(height: 8, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("$_suvCount SUV", style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // --- BAGIAN 3: LIST DATA ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("Belum ada data pada periode ini", style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                )
                : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredLogs[index];

                    final String type = log['type']?.toString() ?? '-';
                    final String floor = log['floor']?.toString() ?? 'Lokasi tidak diketahui';
                    
                    final int timestamp = (log['timestamp'] is num) ? (log['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch;
                    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                    final String dateStr = DateFormat('dd MMM').format(date);
                    final String timeStr = DateFormat('HH:mm').format(date);

                    bool isHighClearance = type.toLowerCase().contains("tinggi");

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          // Kolom Waktu
                          SizedBox(
                            width: 50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(dateStr, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                                Text(timeStr, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Container(height: 35, width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),

                          // Icon Kendaraan
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isHighClearance ? Colors.orange.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isHighClearance ? Icons.local_shipping_outlined : Icons.directions_car_filled_outlined,
                              color: isHighClearance ? Colors.orange : Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Detail Tipe & Lantai
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isHighClearance ? "GC Tinggi (SUV/MPV)" : "GC Rendah (Sedan)",
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                                
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(floor, 
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  ],
                                ),
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
}