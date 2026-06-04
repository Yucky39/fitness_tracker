import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../models/ai_usage.dart';

/// JST基準の `YYYY-MM`。Cloud Functions 側の currentMonthKey() と一致させる。
String currentUsageMonthKey() {
  final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
  final m = jst.month.toString().padLeft(2, '0');
  return '${jst.year}-$m';
}

class AiUsageNotifier extends StateNotifier<AiUsage> {
  AiUsageNotifier() : super(AiUsage.empty) {
    _listen();
  }

  StreamSubscription<DocumentSnapshot>? _sub;

  void _listen() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _sub?.cancel();
      if (user == null) {
        state = AiUsage.empty;
        return;
      }
      _sub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_usage')
          .doc(currentUsageMonthKey())
          .snapshots()
          .listen(
        (snap) {
          if (!snap.exists || snap.data() == null) {
            state = AiUsage.empty;
            return;
          }
          state = AiUsage.fromFirestore(snap.data() as Map<String, dynamic>);
        },
        onError: (_) {
          state = AiUsage.empty;
        },
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final aiUsageProvider =
    StateNotifierProvider<AiUsageNotifier, AiUsage>((_) => AiUsageNotifier());
