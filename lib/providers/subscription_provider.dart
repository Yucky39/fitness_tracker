import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../models/subscription.dart';

class SubscriptionNotifier extends StateNotifier<SubscriptionStatus> {
  SubscriptionNotifier() : super(SubscriptionStatus.empty) {
    _listen();
  }

  StreamSubscription<DocumentSnapshot>? _sub;

  void _listen() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _sub?.cancel();
      if (user == null) {
        state = SubscriptionStatus.empty;
        return;
      }
      _sub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('status')
          .snapshots()
          .listen(
        (snap) {
          if (!snap.exists || snap.data() == null) {
            state = SubscriptionStatus.empty;
            return;
          }
          state = SubscriptionStatus.fromFirestore(
              snap.data() as Map<String, dynamic>);
        },
        onError: (_) {
          state = SubscriptionStatus.empty;
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

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionStatus>(
  (_) => SubscriptionNotifier(),
);

/// サブスク有効かどうかを簡単に読むショートカット
final isSubscribedProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).hasActiveAccess;
});
