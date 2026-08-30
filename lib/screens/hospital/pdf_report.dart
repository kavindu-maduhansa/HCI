import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/blood_request.dart';
import '../../utils/request_status.dart';
import '../../widgets/common_states.dart';

/// #12 - PDF Request Report.
///
/// Builds a professional one-page summary of a request for hospital
/// records / handover. Deliberately excludes donor phone numbers and
/// any other sensitive personal data (#16 donor privacy) - only the
/// donor's name, pledged units, and response status are included,
/// which is what coordination and audit purposes require.
Future<void> generateRequestReport({
  required BuildContext context,
  required BloodRequest request,
  required List<DonorResponseRecord> responses,
  required List<Map<String, dynamic>> auditEntries,
}) async {
  try {
    final doc = pw.Document();
    final generatedAt = DateTime.now();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('LifeLink — Emergency Blood Request Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('Generated: ${_fmt(generatedAt)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Divider(height: 20),

              pw.Text('Request Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _kv('Request ID', request.id),
              _kv('Blood Group', request.bloodGroup),
              _kv('Units Required', '${request.unitsNeeded}'),
              _kv('Units Confirmed', '${request.unitsConfirmed}'),
              _kv('Priority / Urgency', request.urgency),
              _kv('Hospital', request.hospitalName),
              _kv('Location', request.location),
              _kv('Verification Status', RequestStatus.label(request.status)),
              if (request.verifiedBy != null) _kv('Verified By', request.verifiedBy!),
              if (request.rejectionReason != null) _kv('Rejection Reason', request.rejectionReason!),
              pw.SizedBox(height: 14),

              pw.Text('Donor Coordination Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _kv('Donors Notified', '${request.donorsNotifiedCount}'),
              _kv('Donors Accepted', '${request.donorsAcceptedCount}'),
              _kv('Response Rate',
                  request.donorsNotifiedCount == 0
                      ? 'n/a'
                      : '${((request.donorsAcceptedCount / request.donorsNotifiedCount) * 100).round()}%'),
              pw.SizedBox(height: 8),
              if (responses.isEmpty)
                pw.Text('No donors were notified for this request.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.2),
                    1: pw.FlexColumnWidth(1),
                    2: pw.FlexColumnWidth(1.4),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _cell('Donor', bold: true),
                        _cell('Units', bold: true),
                        _cell('Status', bold: true),
                      ],
                    ),
                    ...responses.map(
                      (r) => pw.TableRow(children: [
                        _cell(r.donorName),
                        _cell('${r.unitsPledged}'),
                        _cell(r.status),
                      ]),
                    ),
                  ],
                ),
              pw.SizedBox(height: 14),

              pw.Text('Audit Timeline', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              if (auditEntries.isEmpty)
                pw.Text('No audit entries recorded.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
              else
                ...auditEntries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '${e['timestampLabel']}  —  ${e['action']}  (${e['performedByName'] ?? ''})',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    )),

              pw.SizedBox(height: 18),
              pw.Divider(),
              pw.Text(
                'This report is generated for hospital/blood-bank record keeping. Donor contact details are intentionally omitted.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'LifeLink_Request_${request.id}.pdf',
    );
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(context, 'Could not generate the PDF report. Please try again.');
    }
  }
}

/// History summary PDF - a one-page overview of a (possibly filtered)
/// set of requests, for hospital/blood-bank record keeping. Additive
/// alongside [generateRequestReport]; does not replace it.
Future<void> generateHistorySummaryReport({
  required BuildContext context,
  required List<BloodRequest> requests,
}) async {
  try {
    final doc = pw.Document();
    final generatedAt = DateTime.now();

    final byStatus = <String, int>{};
    for (final r in requests) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
    }
    final fulfilled = byStatus[RequestStatus.fulfilled] ?? 0;
    final totalUnits = requests.fold<int>(0, (t, r) => t + r.unitsNeeded);
    final confirmedUnits = requests.fold<int>(0, (t, r) => t + r.unitsConfirmed);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          pw.Text('LifeLink — Request History Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Generated: ${_fmt(generatedAt)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Divider(height: 20),

          pw.Text('Overview', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _kv('Requests in this report', '${requests.length}'),
          _kv('Fulfilled', '$fulfilled'),
          _kv('Total Units Requested', '$totalUnits'),
          _kv('Total Units Confirmed', '$confirmedUnits'),
          for (final entry in byStatus.entries) _kv('Status: ${RequestStatus.label(entry.key)}', '${entry.value}'),
          pw.SizedBox(height: 14),

          pw.Text('Requests', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (requests.isEmpty)
            pw.Text('No requests match the current filters.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.8),
                1: pw.FlexColumnWidth(0.8),
                2: pw.FlexColumnWidth(0.6),
                3: pw.FlexColumnWidth(1.6),
                4: pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Patient', bold: true),
                    _cell('Group', bold: true),
                    _cell('Units', bold: true),
                    _cell('Hospital', bold: true),
                    _cell('Status', bold: true),
                  ],
                ),
                ...requests.map((r) => pw.TableRow(children: [
                      _cell(r.patientName),
                      _cell(r.bloodGroup),
                      _cell('${r.unitsNeeded}'),
                      _cell(r.hospitalName),
                      _cell(RequestStatus.label(r.status)),
                    ])),
              ],
            ),

          pw.SizedBox(height: 18),
          pw.Divider(),
          pw.Text(
            'This report is generated for hospital/blood-bank record keeping. Donor contact details are intentionally omitted.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'LifeLink_History_Summary.pdf',
    );
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(context, 'Could not generate the PDF report. Please try again.');
    }
  }
}

pw.Widget _kv(String key, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 130, child: pw.Text(key, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
      ],
    ),
  );
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}
