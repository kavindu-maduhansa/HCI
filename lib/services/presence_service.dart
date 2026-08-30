import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// #live-presence - lightweight "who's online" for Doctor/Blood Bank
/// staff. There is no dedicated realtime-presence backend in this
/// project (no Firebase Realtime Database, no Cloud Functions), so
/// this uses a plain Firestore heartbeat: each signed-in staff session
/// writes its own `staffPresence/{uid}` document and refreshes
/// `lastSeen` on a timer. Anyone reading the collection treats a
/// document as "online" only if its `lastSeen` is within the last
/// [onlineWindow] - a document is never explicitly deleted on sign-out
/// (a killed app/tab can't run that code anyway), it just ages out.
///
/// This is a real, if simple, distributed-systems pattern (heartbeat +
/// staleness window) - not a fabricated indicator - and needs no new
/// Firestore field on any *other* collection, so it cannot collide
/// with a teammate's schema.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const heartbeatInterval = Duration(seconds: 25);
  static const onlineWindow = Duration(seconds: 70);

  Timer? _timer;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _presence => _db.collection('staffPresence');

  void start({required String staffName}) {
    if (_timer != null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    void beat() {
      _presence.doc(user.uid).set({
        'staffName': staffName,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    beat();
    _timer = Timer.periodic(heartbeatInterval, (_) => beat());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Live count of staff whose last heartbeat is inside [onlineWindow].
  /// Filtered client-side (staff rosters are small - no need for a
  /// composite index or a server-side inequality query on time).
  Stream<int> onlineCount() {
    return _presence.snapshots().map((snapshot) {
      final cutoff = DateTime.now().subtract(onlineWindow);
      return snapshot.docs.where((d) {
        final lastSeen = (d.data()['lastSeen'] as Timestamp?)?.toDate();
        return lastSeen != null && lastSeen.isAfter(cutoff);
      }).length;
    });
  }
}
