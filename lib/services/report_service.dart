import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  String get initials {
    final parts = namaPenumpang.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return namaPenumpang.isNotEmpty ? namaPenumpang[0].toUpperCase() : '?';
  }
}

// ── Model: hasil lengkap laporan driver ─────────────────────

class DriverReportData {
  final int totalAttendances;
  final List<AttendanceReportRow> rows;

  const DriverReportData({required this.totalAttendances, required this.rows});

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

  Future<DriverReportData?> fetchDriverReport({
    required int busId,
    required String tanggal,
  }) async {
    final resp = await _api.get('/reports/driver', params: {
      'bus_id': busId.toString(),
      'tanggal': tanggal,
    });
    if (!resp.success || resp.data == null) {
      if (kDebugMode)
        debugPrint('[ReportService] fetchDriverReport error: ${resp.message}');
      return null;
    }
    try {
      return DriverReportData.fromJson(resp.data!);
    } catch (e) {
      if (kDebugMode) debugPrint('[ReportService] parse error: $e');
      return null;
    }
  }

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

  // ── Private ───────────────────────────────────────────────

  Future<String?> _downloadFile({
    required String endpoint,
    required Map<String, String> params,
    required String filename,
  }) async {
    try {
      final token = await _api.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': '*/*',
      }).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        if (kDebugMode)
          debugPrint(
              '[ReportService] HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        if (kDebugMode) debugPrint('[ReportService] Response kosong');
        return null;
      }

      final path = await _saveToDownloads(bytes, filename);
      if (kDebugMode) debugPrint('[ReportService] Tersimpan: $path');
      return path;
    } catch (e) {
      if (kDebugMode) debugPrint('[ReportService] Error: $e');
      return null;
    }
  }

  /// Simpan ke folder Download yang TERLIHAT di File Manager Android.
  /// Android <= 28 : minta izin WRITE_EXTERNAL_STORAGE
  /// Android >= 29  : tulis langsung tanpa izin
  Future<String?> _saveToDownloads(Uint8List bytes, String filename) async {
    if (!Platform.isAndroid) {
      // iOS: simpan ke Documents (tampil di app Files)
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }

    // Android: cek SDK version
    final sdkInt = await _getAndroidSdkInt();
    if (kDebugMode) debugPrint('[ReportService] Android SDK: $sdkInt');

    // Android 9 ke bawah perlu izin storage dulu
    if (sdkInt <= 28) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (kDebugMode) debugPrint('[ReportService] Izin storage ditolak');
        return _saveInternal(bytes, filename);
      }
    }

    // Coba semua path Download yang umum di Android
    final candidates = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/storage/sdcard0/Download',
      '/storage/sdcard/Download',
    ];

    for (final folderPath in candidates) {
      try {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          final file = File('$folderPath/$filename');
          await file.writeAsBytes(bytes, flush: true);
          // Verifikasi file benar-benar ada dan tidak kosong
          if (await file.exists() && await file.length() > 0) {
            if (kDebugMode)
              debugPrint('[ReportService] OK: $folderPath/$filename');
            return file.path;
          }
        }
      } catch (e) {
        if (kDebugMode)
          debugPrint('[ReportService] Gagal tulis ke $folderPath: $e');
        continue;
      }
    }

    // Fallback 1: getExternalStorageDirectory
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final file = File('${extDir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        if (await file.exists() && await file.length() > 0) {
          if (kDebugMode)
            debugPrint('[ReportService] External storage: ${extDir.path}');
          return file.path;
        }
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('[ReportService] getExternalStorageDirectory error: $e');
    }

    // Fallback 2: internal app (tetap bisa dibuka via OpenFilex)
    return _saveInternal(bytes, filename);
  }

  Future<String> _saveInternal(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    if (kDebugMode)
      debugPrint('[ReportService] Internal fallback: ${file.path}');
    return file.path;
  }

  Future<int> _getAndroidSdkInt() async {
    try {
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 30;
    } catch (_) {
      return 30; // Default: Android 11, tidak perlu izin
    }
  }
}
