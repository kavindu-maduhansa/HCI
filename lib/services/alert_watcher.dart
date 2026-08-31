import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blood_request.dart';
import 'request_service.dart';

/// Watches the `requests` collection for newly created requests that
/// deserve a proactive alert (critical urgency, or simply awaiting
/// verification) and writes them into the in-app `alerts` collection
/// via [RequestService]. Deterministic alert doc IDs mean this is
/// safe to run from more than one signed-in doctor session at once -
/// duplicates are merged, not re-created.
///
/// No Firebase Cloud Messaging is configured in this project yet, so
/// this Firestore-only approach is used instead, per the module spec
/// (#8 Smart Alert Center).
class AlertWatcher {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final _service = RequestService.instance;

  void start() {
    _sub ??= FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final request = BloodRequest.fromDoc(change.doc);
        if (request.urgency == 'Critical') {
          _service.createCriticalRequestAlert(request);
        } else {
          _service.createPendingVerificationAlert(request);
        }
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
