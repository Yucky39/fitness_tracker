import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService().authStateChanges;
});
