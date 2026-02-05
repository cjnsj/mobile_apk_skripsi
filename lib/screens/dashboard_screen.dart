import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Wajib untuk format tanggal
import 'report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _dbRefSystem =
      FirebaseDatabase.instance.ref('parking_system');
  final DatabaseReference _dbRefLogs =
      FirebaseDatabase.instance.ref('parking_logs');

  // Variabel Data Status
  int totalFree = 0;
  int totalCapacity = 0;
  int l1Free = 0;
  int l1Capacity = 0;
  int l2Free = 0;
  int l2Capacity = 0;

  // Variabel Data Chart
  List<double> weeklyCounts = [0, 0, 0, 0, 0, 0, 0];
  double maxChartY = 10;

  // Variabel Informasi Waktu
  String periodText = "Memuat...";
  String weekNumberText = "";

  @override
  void initState() {
    super.initState();
    _calculateCurrentWeek(); // Hitung tanggal minggu ini dulu
    _listenToStatus();
    _listenToLogs();
  }

  // --- LOGIKA TANGGAL & MINGGU ---
  DateTime _startOfWeek = DateTime.now();
  DateTime _endOfWeek = DateTime.now();

  void _calculateCurrentWeek() {
    DateTime now = DateTime.now();
    // Cari hari Senin minggu ini (weekday 1 = Senin)
    _startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    _startOfWeek = DateTime(_startOfWeek.year, _startOfWeek.month,
        _startOfWeek.day, 0, 0, 0); // Jam 00:00

    // Cari hari Minggu (Senin + 6 hari)
    _endOfWeek = _startOfWeek.add(const Duration(
        days: 6, hours: 23, minutes: 59, seconds: 59)); // Jam 23:59

    // Format Teks untuk UI
    // Contoh: "10 Feb - 16 Feb 2024"
    String startStr = DateFormat('d MMM').format(_startOfWeek);
    String endStr = DateFormat('d MMM yyyy').format(_endOfWeek);

    // Hitung Minggu ke-berapa dalam tahun ini
    int dayOfYear = int.parse(DateFormat("D").format(now));
    int weekNum = ((dayOfYear - now.weekday + 10) / 7).floor();

    setState(() {
      periodText = "$startStr - $endStr";
      weekNumberText = "Minggu ke-$weekNum";
    });
  }

  // 1. Ambil Status Kapasitas
  void _listenToStatus() {
    _dbRefSystem.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            totalFree = int.tryParse(data['total_free'].toString()) ?? 0;
            totalCapacity =
                int.tryParse(data['total_capacity'].toString()) ?? 0;
            l1Free = int.tryParse(data['l1_free'].toString()) ?? 0;
            l1Capacity = int.tryParse(data['l1_capacity'].toString()) ?? 0;
            l2Free = int.tryParse(data['l2_free'].toString()) ?? 0;
            l2Capacity = int.tryParse(data['l2_capacity'].toString()) ?? 0;
          });
        }
      }
    });
  }

  // 2. Ambil Log & Filter HANYA Minggu Ini
  void _listenToLogs() {
    _dbRefLogs.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        List<double> tempCounts = [0, 0, 0, 0, 0, 0, 0];
        double maxVal = 0;

        data.forEach((key, value) {
          final log = value as Map<dynamic, dynamic>;
          if (log['timestamp'] != null) {
            int ts = int.tryParse(log['timestamp'].toString()) ?? 0;
            if (ts > 0) {
              DateTime logDate = DateTime.fromMillisecondsSinceEpoch(ts);

              // --- FILTER PENTING ---
              // Hanya hitung jika logDate ada di antara Senin 00:00 s/d Minggu 23:59 minggu ini
              if (logDate.isAfter(
                      _startOfWeek.subtract(const Duration(seconds: 1))) &&
                  logDate
                      .isBefore(_endOfWeek.add(const Duration(seconds: 1)))) {
                int dayIndex = logDate.weekday - 1; // Senin(1) jadi index 0
                if (dayIndex >= 0 && dayIndex < 7) {
                  tempCounts[dayIndex]++;
                }
              }
            }
          }
        });

        // Cari nilai max untuk skala chart
        for (var val in tempCounts) {
          if (val > maxVal) maxVal = val;
        }

        if (mounted) {
          setState(() {
            weeklyCounts = tempCounts;
            maxChartY = maxVal == 0 ? 10 : maxVal + 5;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double progressL1 =
        l1Capacity > 0 ? (l1Capacity - l1Free) / l1Capacity : 0.0;
    double progressL2 =
        l2Capacity > 0 ? (l2Capacity - l2Free) / l2Capacity : 0.0;
    double totalOccupancy =
        totalCapacity > 0 ? (totalCapacity - totalFree) / totalCapacity : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_parking_rounded,
                  color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Text(
              "Smart Parking",
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === HERO CARD ===
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.white.withOpacity(0.1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Status Area Parkir",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text("Live Update",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 10)),
                            )
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("$totalFree",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0)),
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8, left: 8),
                              child: Text("/ $totalCapacity Tersedia",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalOccupancy,
                                minHeight: 6,
                                backgroundColor: Colors.black.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                "Kapasitas Terpakai: ${(totalOccupancy * 100).toStringAsFixed(0)}%",
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // === BAGIAN CHART DENGAN INFO TANGGAL ===
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Statistik Kunjungan",
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                // Badge Minggu Ke-X
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    weekNumberText, // Contoh: "Minggu ke-7"
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Teks Tanggal Periode
            Text(
              periodText, // Contoh: "10 Feb - 16 Feb 2025"
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),

            const SizedBox(height: 12),

            // Container Chart
            Container(
              height: 250,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxChartY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueAccent,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.round()} Mobil',
                          GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12);
                          String text;
                          switch (value.toInt()) {
                            case 0:
                              text = 'Sen';
                              break;
                            case 1:
                              text = 'Sel';
                              break;
                            case 2:
                              text = 'Rab';
                              break;
                            case 3:
                              text = 'Kam';
                              break;
                            case 4:
                              text = 'Jum';
                              break;
                            case 5:
                              text = 'Sab';
                              break;
                            case 6:
                              text = 'Min';
                              break;
                            default:
                              text = '';
                          }
                          return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(text, style: style));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _makeBarGroup(0, weeklyCounts[0], Colors.blue.shade300),
                    _makeBarGroup(1, weeklyCounts[1], Colors.blue.shade300),
                    _makeBarGroup(2, weeklyCounts[2], Colors.blue.shade300),
                    _makeBarGroup(3, weeklyCounts[3], Colors.blue.shade300),
                    _makeBarGroup(4, weeklyCounts[4], Colors.blue.shade300),
                    _makeBarGroup(5, weeklyCounts[5], Colors.redAccent),
                    _makeBarGroup(6, weeklyCounts[6], Colors.redAccent),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // === DETAIL LANTAI ===
            Text("Detail Lantai",
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildFloorCard(
                        title: "Lantai 1",
                        free: l1Free,
                        capacity: l1Capacity,
                        progress: progressL1,
                        color: Colors.blueAccent,
                        icon: Icons.directions_car_filled)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildFloorCard(
                        title: "Lantai 2",
                        free: l2Free,
                        capacity: l2Capacity,
                        progress: progressL2,
                        color: Colors.purpleAccent,
                        icon: Icons.local_taxi)),
              ],
            ),

            const SizedBox(height: 30),

            // === MENU REPORT ===
            InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReportScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.history_edu_rounded,
                          color: Colors.orange, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Laporan Riwayat",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Lihat log keluar masuk kendaraan",
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    Color barColor = y > 5 ? Colors.orange : color;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: barColor,
          width: 16,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxChartY,
            color: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildFloorCard(
      {required String title,
      required int free,
      required int capacity,
      required double progress,
      required Color color,
      required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$free",
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              Text("/$capacity",
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
