import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Central service for Food Flow legal agreement versioning and consent management.
class FoodFlowConsentService extends ChangeNotifier {
  static final FoodFlowConsentService instance = FoodFlowConsentService._internal();
  factory FoodFlowConsentService() => instance;
  FoodFlowConsentService._internal();

  /// Current active legal policy version identifier
  static const String currentTermsVersion = 'foodflow_terms_v1';

  /// SharedPreferences keys
  static const String prefVersionKey = 'foodflow_terms_accepted_version';
  static const String prefTimestampKey = 'foodflow_terms_accepted_at';
  static const String prefConsentActiveKey = 'foodflow_terms_consent_active';
  static const String prefHasReadTermsKey = 'foodflow_terms_has_read_terms';
  static const String prefHasReadPrivacyKey = 'foodflow_terms_has_read_privacy';

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isConsentActive = false;
  bool _hasReadTerms = false;
  bool _hasReadPrivacy = false;
  String? _acceptedVersion;
  DateTime? _acceptedAt;

  bool get isInitialized => _isInitialized;
  bool get isConsentActive => _isConsentActive;
  bool get hasReadTerms => _hasReadTerms || hasAcceptedCurrentTermsSync();
  bool get hasReadPrivacy => _hasReadPrivacy || hasAcceptedCurrentTermsSync();
  bool get hasReadBothDocuments => hasReadTerms && hasReadPrivacy;
  String? get acceptedVersion => _acceptedVersion;
  DateTime? get acceptedAt => _acceptedAt;

  /// Returns true if the user has actively accepted the CURRENT version of terms
  bool hasAcceptedCurrentTermsSync() {
    return _isConsentActive && _acceptedVersion == currentTermsVersion;
  }

  /// Initialize local consent state from SharedPreferences
  Future<void> initialize({SharedPreferences? customPrefs}) async {
    try {
      _prefs = customPrefs ?? await SharedPreferences.getInstance();
      _acceptedVersion = _prefs?.getString(prefVersionKey);
      final rawTimestamp = _prefs?.getString(prefTimestampKey);
      if (rawTimestamp != null && rawTimestamp.isNotEmpty) {
        _acceptedAt = DateTime.tryParse(rawTimestamp);
      }
      final bool hasActivePref = _prefs?.getBool(prefConsentActiveKey) ?? (_acceptedVersion == currentTermsVersion);
      _isConsentActive = hasActivePref && (_acceptedVersion == currentTermsVersion);
      _hasReadTerms = _prefs?.getBool(prefHasReadTermsKey) ?? _isConsentActive;
      _hasReadPrivacy = _prefs?.getBool(prefHasReadPrivacyKey) ?? _isConsentActive;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FoodFlowConsentService init error: $e');
      _isInitialized = true;
    }
  }

  /// Mark Terms & Conditions as read to the bottom
  Future<void> markTermsAsRead() async {
    if (_hasReadTerms) return;
    _hasReadTerms = true;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(prefHasReadTermsKey, true);
    } catch (_) {}
    notifyListeners();
  }

  /// Mark Privacy Policy as read to the bottom
  Future<void> markPrivacyAsRead() async {
    if (_hasReadPrivacy) return;
    _hasReadPrivacy = true;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(prefHasReadPrivacyKey, true);
    } catch (_) {}
    notifyListeners();
  }

  /// Records explicit user consent for the specified or current version
  Future<void> recordConsent({
    String? version,
    DateTime? timestamp,
    String? userId,
  }) async {
    final ver = version ?? currentTermsVersion;
    final time = timestamp ?? DateTime.now().toUtc();

    _acceptedVersion = ver;
    _acceptedAt = time;
    _isConsentActive = (ver == currentTermsVersion);
    _hasReadTerms = true;
    _hasReadPrivacy = true;

    // 1. Persist to SharedPreferences
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(prefVersionKey, ver);
      await _prefs?.setString(prefTimestampKey, time.toIso8601String());
      await _prefs?.setBool(prefConsentActiveKey, true);
      await _prefs?.setBool(prefHasReadTermsKey, true);
      await _prefs?.setBool(prefHasReadPrivacyKey, true);
    } catch (e) {
      debugPrint('Failed to persist consent locally: $e');
    }

    // 2. Associate with authenticated user profile in Supabase if session exists
    final targetUid = userId ?? SupabaseService.currentUser?.id;
    if (targetUid != null && SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('profiles').update({
          'terms_accepted_version': ver,
          'terms_accepted_at': time.toIso8601String(),
          'terms_consent_active': true,
        }).eq('id', targetUid);
      } catch (e) {
        debugPrint('Consent sync to remote profile note: $e');
      }
    }

    notifyListeners();
  }

  /// Revokes active consent while preserving historical audit timestamps and versions
  Future<void> revokeConsent({String? userId}) async {
    _isConsentActive = false;

    // 1. Persist revocation flag locally
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(prefConsentActiveKey, false);
    } catch (e) {
      debugPrint('Failed to save revocation locally: $e');
    }

    // 2. Update Supabase profile active flag
    final targetUid = userId ?? SupabaseService.currentUser?.id;
    if (targetUid != null && SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('profiles').update({
          'terms_consent_active': false,
        }).eq('id', targetUid);
      } catch (e) {
        debugPrint('Revoke consent sync note: $e');
      }
    }

    notifyListeners();
  }

  /// Synchronize consent with fetched UserProfile from Supabase
  Future<void> checkAndSyncWithProfile(UserProfile? profile) async {
    if (profile == null) return;

    if (profile.termsAcceptedVersion == currentTermsVersion && profile.isTermsConsentActive) {
      // Profile has active current version, update local state if needed
      if (!hasAcceptedCurrentTermsSync()) {
        _acceptedVersion = profile.termsAcceptedVersion;
        _acceptedAt = profile.termsAcceptedAt ?? DateTime.now().toUtc();
        _isConsentActive = true;
        _hasReadTerms = true;
        _hasReadPrivacy = true;
        try {
          _prefs ??= await SharedPreferences.getInstance();
          await _prefs?.setString(prefVersionKey, _acceptedVersion!);
          await _prefs?.setString(prefTimestampKey, _acceptedAt!.toIso8601String());
          await _prefs?.setBool(prefConsentActiveKey, true);
          await _prefs?.setBool(prefHasReadTermsKey, true);
          await _prefs?.setBool(prefHasReadPrivacyKey, true);
        } catch (_) {}
        notifyListeners();
      }
    } else if (hasAcceptedCurrentTermsSync()) {
      // Local state has valid active consent but remote profile doesn't have it yet; sync upwards
      try {
        if (SupabaseService.isInitialized) {
          await SupabaseService.client.from('profiles').update({
            'terms_accepted_version': _acceptedVersion,
            'terms_accepted_at': (_acceptedAt ?? DateTime.now().toUtc()).toIso8601String(),
            'terms_consent_active': true,
          }).eq('id', profile.id);
        }
      } catch (_) {}
    }
  }

  /// Reset or configure consent for automated testing and policy version simulations
  void resetForTesting({
    bool accepted = false,
    bool hasRead = false,
    bool hasReadTerms = false,
    bool hasReadPrivacy = false,
    String? overrideVersion,
    DateTime? overrideTimestamp,
  }) {
    _isConsentActive = accepted;
    _hasReadTerms = hasRead || hasReadTerms || accepted;
    _hasReadPrivacy = hasRead || hasReadPrivacy || accepted;
    _acceptedVersion = overrideVersion ?? (accepted ? currentTermsVersion : null);
    _acceptedAt = overrideTimestamp ?? (accepted ? DateTime.now().toUtc() : null);
    _isInitialized = true;
    notifyListeners();
  }
}
