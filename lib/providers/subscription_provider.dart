import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

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

/// 購入はストアで完了したがサーバー反映待ちの場合 true。
/// ペイウォールを誤表示しないために参照する。
class _PendingActivationNotifier extends StateNotifier<bool> {
  _PendingActivationNotifier() : super(false) {
    _init();
    _sub = SubscriptionService().activationEvents.listen((event) {
      if (event.status == SubscriptionActivationStatus.success) {
        state = false;
      } else {
        _refresh();
      }
    });
  }

  StreamSubscription<SubscriptionActivationEvent>? _sub;

  Future<void> _init() async => state = await _hasPending();
  Future<void> _refresh() async => state = await _hasPending();

  Future<bool> _hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pending_activations');
    if (raw == null || raw.isEmpty) return false;
    try {
      return (jsonDecode(raw) as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final hasPendingActivationProvider =
    StateNotifierProvider<_PendingActivationNotifier, bool>(
  (_) => _PendingActivationNotifier(),
);
