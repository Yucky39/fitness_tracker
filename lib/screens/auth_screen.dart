import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../providers/achievement_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/training_plan_provider.dart';
import '../providers/water_provider.dart';
import '../widgets/bewell_logo.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'メールアドレスを入力してください';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
      return '有効なメールアドレスを入力してください';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'パスワードを入力してください';
    if (value.length < 6) return 'パスワードは6文字以上にしてください';
    return null;
  }

  void _reloadProviders() {
    ref.invalidate(energyProfileProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(achievementProvider);
    ref.invalidate(mealProvider);
    ref.invalidate(waterProvider);
    ref.invalidate(trainingPlanProvider);
    ref.invalidate(presetProvider);
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService().signIn(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      // Merge Firestore data (SQLite + SharedPreferences) into local storage
      await SyncService().downloadAndMergeData();
      if (!mounted) return;
      // Reload providers so they pick up the downloaded data
      _reloadProviders();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _localizeAuthError(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'ログインに失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (_registerPasswordController.text != _registerConfirmController.text) {
      if (!mounted) return;
      setState(() => _errorMessage = 'パスワードが一致しません');
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService().signUp(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
      );
      if (!mounted) return;
      // Upload existing local data (SQLite + SharedPreferences) to Firestore
      await SyncService().uploadAllData();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _localizeAuthError(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'アカウント作成に失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithSocial(
      Future<UserCredential> Function() signInMethod) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final credential = await signInMethod();
      if (!mounted) return;
      final isNew = credential.additionalUserInfo?.isNewUser ?? false;
      if (isNew) {
        await SyncService().uploadAllData();
      } else {
        await SyncService().downloadAndMergeData();
      }
      if (!mounted) return;
      _reloadProviders();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _localizeAuthError(e.code));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!mounted) return;
      setState(() => _errorMessage = 'Appleログインに失敗しました');
    } catch (e) {
      if (e.toString().contains('キャンセル')) return;
      if (!mounted) return;
      setState(() => _errorMessage = 'ログインに失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _loginEmailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = 'パスワードリセットにはメールアドレスを入力してください');
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService().resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードリセットのメールを送信しました')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _localizeAuthError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _localizeAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'このメールアドレスのアカウントが見つかりません';
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが正しくありません';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上にしてください）';
      case 'invalid-email':
        return '有効なメールアドレスを入力してください';
      case 'too-many-requests':
        return '試行回数が多すぎます。しばらくしてからお試しください';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。接続を確認してください';
      case 'keychain-error':
        return 'macOS のキーチェーンにアクセスできません。'
            'Xcode で Runner の Signing に開発チームを設定し、'
            'クリーンビルドしてから再度お試しください';
      case 'operation-not-allowed':
        return 'このログイン方法は Firebase で無効です。'
            'Firebase コンソールの「Authentication」→「Sign-in method」で'
            '「メール/パスワード」を有効にしてください';
      case 'user-disabled':
        return 'このアカウントは無効化されています。管理者にお問い合わせください';
      default:
        return 'エラーが発生しました（$code）';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / header
                  const BeWellLogo(size: 64, showLabel: true),
                  const SizedBox(height: 8),
                  Text(
                    '複数のデバイスでデータを同期',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: colorScheme.onPrimary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'ログイン'),
                        Tab(text: '新規登録'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: colorScheme.onErrorContainer, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tab views
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // OR divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'または',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Social login buttons
                  _buildSocialButton(
                    label: 'Googleでログイン',
                    color: Colors.white,
                    textColor: Colors.black87,
                    borderColor: Colors.grey.shade300,
                    icon: _GoogleIcon(),
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithSocial(
                            AuthService().signInWithGoogle),
                  ),
                  const SizedBox(height: 10),
                  _buildSocialButton(
                    label: 'Appleでログイン',
                    color: Colors.black,
                    textColor: Colors.white,
                    icon: const Icon(Icons.apple, color: Colors.white, size: 20),
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithSocial(
                            AuthService().signInWithApple),
                  ),
                  const SizedBox(height: 10),
                  _buildSocialButton(
                    label: 'Xでログイン',
                    color: Colors.black,
                    textColor: Colors.white,
                    icon: const _XIcon(),
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithSocial(
                            AuthService().signInWithTwitter),
                  ),
                  const SizedBox(height: 10),
                  _buildSocialButton(
                    label: 'Metaでログイン',
                    color: const Color(0xFF1877F2),
                    textColor: Colors.white,
                    icon: const _MetaIcon(),
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithSocial(
                            AuthService().signInWithFacebook),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required Color color,
    required Color textColor,
    required Widget icon,
    Color? borderColor,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          side: borderColor != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: icon),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _emailValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: !_loginPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'パスワード',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_loginPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () => setState(
                    () => _loginPasswordVisible = !_loginPasswordVisible),
              ),
            ),
            validator: _passwordValidator,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: const Text('パスワードを忘れた場合'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('ログイン'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _emailValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: !_registerPasswordVisible,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'パスワード（6文字以上）',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_registerPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () => setState(() =>
                    _registerPasswordVisible = !_registerPasswordVisible),
              ),
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerConfirmController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _register(),
            decoration: const InputDecoration(
              labelText: 'パスワード（確認）',
              prefixIcon: Icon(Icons.lock_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'パスワードを再入力してください';
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('アカウントを作成'),
          ),
        ],
      ),
    );
  }
}

// ── Brand icon widgets ────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.35, 4.25, false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22,
    );
    // Red arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.9, 0.75, false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22,
    );
    // Yellow arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, 1.22, false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22,
    );
    // Green arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.35, 0.0, false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22,
    );
    // Horizontal bar
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.5, size.height * 0.35, size.width * 0.46, size.height * 0.3),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _XIcon extends StatelessWidget {
  const _XIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '𝕏',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'f',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'serif',
      ),
    );
  }
}
