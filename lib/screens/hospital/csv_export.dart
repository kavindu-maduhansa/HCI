import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/blood_request.dart';
import '../../utils/request_status.dart';

/// #csv-export - CSV export for the History tab's (possibly filtered)
/// request list, so a doctor can pull the exact rows on screen into
/// Excel/Sheets for further analysis, alongside the existing PDF
/// summary export.
///
/// Delivery strategy: always copies the CSV text to the clipboard -
/// this works identically on every platform (web included) with no
/// extra plumbing, and "paste into a spreadsheet" is how most staff
/// actually get data into Excel anyway. On Windows/macOS/Linux
/// desktop it additionally writes the CSV straight to disk (Downloads
/// folder), same approach as the PDF exports in pdf_report.dart,
/// since a native "download" dialog is not reliably available there.
Future<void> exportRequestsAsCsv({
  required BuildContext context,
  required List<BloodRequest> requests,
}) async {
  final csv = _buildCsv(requests);
  await Clipboard.setData(ClipboardData(text: csv));

  String? savedPath;
  if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}LifeLink_History_${_fileStamp(DateTime.now())}.csv');
      await file.writeAsString(csv);
      savedPath = file.path;
    } catch (_) {
      // The clipboard copy above already succeeded, so a disk-write
      // failure here isn't fatal - the export still worked.
    }
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        savedPath != null
            ? 'CSV copied to clipboard and saved: $savedPath'
            : 'CSV copied to clipboard (${requests.length} row${requests.length == 1 ? '' : 's'}) - paste into Excel or Sheets.',
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}

String _buildCsv(List<BloodRequest> requests) {
  final rows = <List<String>>[
    ['Request ID', 'Patient', 'Blood Group', 'Units Needed', 'Units Confirmed', 'Urgency', 'Hospital', 'Location', 'Status', 'Verified By', 'Created At'],
    for (final r in requests)
      [
        r.id,
        r.patientName,
        r.bloodGroup,
        '${r.unitsNeeded}',
        '${r.unitsConfirmed}',
        r.urgency,
        r.hospitalName,
        r.location,
        RequestStatus.label(r.status),
        r.verifiedBy ?? '',
        r.createdAt?.toIso8601String() ?? '',
      ],
  ];
  return rows.map((row) => row.map(_escapeCsvField).join(',')).join('\r\n');
}

/// Standard CSV field escaping (RFC 4180): wrap in quotes and double
/// any embedded quotes whenever the field contains a comma, quote, or
/// newline - patient names and hospital names are free text and can
/// contain any of these.
String _escapeCsvField(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

String _fileStamp(DateTime dt) {
  final l = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}${two(l.month)}${two(l.day)}_${two(l.hour)}${two(l.minute)}';
}
