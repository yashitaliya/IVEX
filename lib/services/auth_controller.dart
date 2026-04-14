import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class AuthController extends ChangeNotifier {
  final AppwriteService _appwrite = AppwriteService();

  late final Account _account;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  String _displayName = '';
  String _email = '';
  bool _isEmailVerified = false;
  bool _isBusy = false;
  String? _pendingOtpUserId;
  String _rememberedEmail = '';
  bool _hasSeenWelcome = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  String get displayName => _displayName;
  String get email => _email;
  bool get isEmailVerified => _isEmailVerified;
  bool get isBusy => _isBusy;
  bool get hasPendingOtp => _pendingOtpUserId != null;
  String get rememberedEmail => _rememberedEmail;
  bool get hasSeenWelcome => _hasSeenWelcome;

  Future<void> initialize() async {
    _appwrite.init();
    _account = Account(_appwrite.appwriteClient);
    final prefs = await SharedPreferences.getInstance();
    _rememberedEmail = prefs.getString('rememberedEmail') ?? '';
    _hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

    try {
      final user = await _account.get();
      _setAuthenticatedUser(user);
    } on AppwriteException catch (e) {
      if (e.code != 401) {
        rethrow;
      }
      _isAuthenticated = false;
      _displayName = '';
      _email = '';
      _isEmailVerified = false;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _setBusy(true);
    try {
      await _account.createEmailPasswordSession(
        email: email.trim(),
        password: password,
      );
      _rememberedEmail = rememberMe ? email.trim() : '';
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('rememberedEmail', _rememberedEmail);
      } else {
        await prefs.remove('rememberedEmail');
      }
      final user = await _account.get();
      _setAuthenticatedUser(user);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> requestEmailOtp({
    required String email,
  }) async {
    _setBusy(true);
    try {
      final token = await _account.createEmailToken(
        userId: ID.unique(),
        email: email.trim(),
      );
      _pendingOtpUserId = token.userId;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> verifyEmailOtp({
    required String otp,
  }) async {
    final userId = _pendingOtpUserId;
    if (userId == null) {
      throw AppwriteException(
        'No OTP request in progress. Please verify email first.',
      );
    }

    _setBusy(true);
    try {
      await _account.createSession(
        userId: userId,
        secret: otp.trim(),
      );
      final user = await _account.get();
      _pendingOtpUserId = null;
      _setAuthenticatedUser(user);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> completeProfile({
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    _setBusy(true);
    try {
      await _account.updateName(name: fullName.trim());
      await _account.updatePassword(password: password);
      await _account.updatePhone(
        phone: phoneNumber.trim(),
        password: password,
      );
      await _account.createEmailVerification(
        url: AppwriteConfig.emailVerificationRedirectUrl,
      );
      final user = await _account.get();
      _setAuthenticatedUser(user);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setBusy(true);
    try {
      await _account.createOAuth2Session(
        provider: OAuthProvider.google,
        success: AppwriteConfig.authSuccessUrl,
        failure: AppwriteConfig.authFailureUrl,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> sendEmailVerification() async {
    _setBusy(true);
    try {
      await _account.createEmailVerification(
        url: AppwriteConfig.emailVerificationRedirectUrl,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> sendPasswordRecovery({
    required String email,
  }) async {
    _setBusy(true);
    try {
      await _account.createRecovery(
        email: email.trim(),
        url: AppwriteConfig.passwordRecoveryRedirectUrl,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (e) {
      if (e.code != 401) {
        rethrow;
      }
    } finally {
      _isAuthenticated = false;
      _displayName = '';
      _email = '';
      _isEmailVerified = false;
      _setBusy(false);
    }
  }

  Future<void> setWelcomeSeen() async {
    _hasSeenWelcome = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    notifyListeners();
  }

  void _setBusy(bool busy) {
    _isBusy = busy;
    notifyListeners();
  }

  void _setAuthenticatedUser(User user) {
    _displayName = user.name.trim().isEmpty ? _nameFromEmail(user.email) : user.name;
    _email = user.email;
    _isEmailVerified = user.emailVerification;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> deleteCurrentAccount({
    required String password,
  }) async {
    _setBusy(true);
    try {
      final user = await _account.get();
      await _account.createEmailPasswordSession(
        email: user.email,
        password: password,
      );
      await _account.updateStatus();
      await _account.deleteSession(sessionId: 'current');
      _isAuthenticated = false;
      _displayName = '';
      _email = '';
      _isEmailVerified = false;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> updateProfileName(String name) async {
    _setBusy(true);
    try {
      await _account.updateName(name: name.trim());
      final user = await _account.get();
      _setAuthenticatedUser(user);
    } finally {
      _setBusy(false);
    }
  }

  String _nameFromEmail(String email) {
    final clean = email.trim();
    if (!clean.contains('@')) return 'IVEX User';

    final raw = clean.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
    final words = raw
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .toList();

    return words.isEmpty ? 'IVEX User' : words.join(' ');
  }
}
