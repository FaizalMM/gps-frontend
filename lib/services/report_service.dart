import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';

// ── Model: satu baris laporan absensi siswa ──────────────────

class AttendanceReportRow {
  final int no;
  final String namaPenumpang;
  final String? waktuNaik;
  final String halteNaik;
  final String? waktuTurun;
  final String? latLngTurun;
  final bool checkout;
  final String plat;
  final String noTelepon;

  const AttendanceReportRow({
    required this.no,
    required this.namaPenumpang,
    this.waktuNaik,
    required this.halteNaik,
    this.waktuTurun,
    this.latLngTurun,
    required this.checkout,
    required this.plat,
    required this.noTelepon,
  });

  factory AttendanceReportRow.fromJson(Map<String, dynamic> json) {
    return AttendanceReportRow(
      no: json['no'] as int? ?? 0,
      namaPenumpang: json['nama_penumpang'] as String? ?? '-',
      waktuNaik: json['waktu_naik'] as String?,
      halteNaik: json['halte_naik'] as String? ?? '-',
      waktuTurun: json['waktu_turun'] as String?,
      latLngTurun: json['lat_lng_turun'] as String?,
      checkout: (json['checkout'] as String? ?? 'No') == 'Yes',
      plat: json['plat'] as String? ?? '-',
      noTelepon: json['no_telepon'] as String? ?? '-',
    );
  }

  /// Format waktu HH:mm dari string datetime
  String get waktuNaikFormatted {
    if (waktuNaik == null) return '-';
    try {
      final dt = DateTime.parse(waktuNaik!).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return waktuNaik!;
    }
  }

  String get waktuTurunFormatted {
    if (waktuTurun == null) return '-';
    try {
      final dt = DateTime.parse(waktuTurun!).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return waktuTurun!;
    }
  }

  /// Inisial dari nama penumpang
  String get initials {
    final parts = namaPenumpang.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return namaPenumpang.isNotEmpty ? namaPenumpang[0].toUpperCase() : '?';
  }
}

// ── Model: hasil lengkap laporan driver ─────────────────────

class DriverReportData {
  final int totalAttendances;
  final List<AttendanceReportRow> rows;

  const DriverReportData({
    required this.totalAttendances,
    required this.rows,
  });

  factory DriverReportData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final rawRows = data['reports'] as List<dynamic>? ?? [];
    return DriverReportData(
      totalAttendances: data['total_attendances'] as int? ?? rawRows.length,
      rows: rawRows
          .map((e) => AttendanceReportRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Service ──────────────────────────────────────────────────

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final _api = ApiClient();

  /// Ambil data laporan driver (JSON) dari endpoint GET /reports/driver
  Future<DriverReportData?> fetchDriverReport({
    required int busId,
    required String tanggal, // format: YYYY-MM-DD
  }) async {
    final resp = await _api.get(
      '/reports/driver',
      params: {
        'bus_id': busId.toString(),
        'tanggal': tanggal,
      },
    );
    if (!resp.success || resp.data == null) {
      if (kDebugMode) debugPrint('[ReportService] fetchDriverReport error: ${resp.message}');
      return null;
    }
    try {
      return DriverReportData.fromJson(resp.data!);
    } catch (e) {
      if (kDebugMode) debugPrint('[ReportService] parse error: $e');
      return null;
    }
  }

  /// Download PDF laporan driver → kembalikan path file tersimpan
  Future<String?> downloadDriverReportPdf({
    required int busId,
    required String tanggal,
    String? catatanDriver,
  }) async {
    return _downloadFile(
      endpoint: '/reports/driver/download-pdf',
      params: {
        'bus_id': busId.toString(),
        'tanggal': tanggal,
        if (catatanDriver != null) 'catatan_driver': catatanDriver,
      },
      filename: 'laporan_driver_${busId}_$tanggal.pdf',
    );
  }

  /// Download Excel laporan driver → kembalikan path file tersimpan
  Future<String?> downloadDriverReportExcel({
    required int busId,
    required String tanggal,
    String? catatanDriver,
  }) async {
    return _downloadFile(
      endpoint: '/reports/driver/download-excel',
      params: {
        'bus_id': busId.toString(),
        'tanggal': tanggal,
        if (catatanDriver != null) 'catatan_driver': catatanDriver,
      },
      filename: 'laporan_driver_${busId}_$tanggal.xlsx',
    );
  }

  // ── Private: lakukan HTTP GET dan simpan bytes ke file ───────

  Future<String?> _downloadFile({
    required String endpoint,
    required Map<String, String> params,
    required String filename,
  }) async {
    try {
      final token = await _api.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[ReportService] download error ${response.statusCode}');
        }
        return null;
      }

      final bytes = response.bodyBytes;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[ReportService] _downloadFile error: $e');
      return null;
    }
  }
}