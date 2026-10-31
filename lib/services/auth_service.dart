import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String role; // 'provider' or 'receiver'
  final String? organizationName;
  final String? phone;
  final String? operatingLocation;
  final bool isVerified;
  final String? termsAcceptedVersion;
  final DateTime? termsAcceptedAt;
  final bool isTermsConsentActive;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.organizationName,
    this.phone,
    this.operatingLocation,
    this.isVerified = true,
    this.termsAcceptedVersion,
    this.termsAcceptedAt,
    this.isTermsConsentActive = true,
  });

  bool get isProvider => role == 'provider';
  bool get isReceiver => role == 'receiver';
  bool get isVolunteer => role == 'volunteer';

  String get roleDisplay => switch (role) {
    'receiver' => 'NGO / Receiver',
    'volunteer' => 'Rescue Volunteer',
    _ => 'Food Provider',
  };

  String get displayName =>
      (organizationName != null && organizationName!.trim().isNotEmpty)
          ? organizationName!.trim()
          : (fullName != null && fullName!.trim().isNotEmpty
              ? fullName!.trim()
              : (email.isNotEmpty ? email.split('@').first : 'FoodFlow Partner'));

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile.fromMap(json);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawRole = switch ((map['role'] ?? 'provider').toString().trim().toLowerCase()) {
      'receiver' => 'receiver',
      'volunteer' => 'volunteer',
      _ => 'provider',
    };

    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString(),
      role: rawRole,
      organizationName: map['organization_name']?.toString(),
      phone: map['phone']?.toString(),
      operatingLocation: map['operating_location']?.toString(),
      isVerified: map['is_verified'] == true,
      termsAcceptedVersion: map['terms_accepted_version']?.toString(),
      termsAcceptedAt: map['terms_accepted_at'] != null
          ? DateTime.tryParse(map['terms_accepted_at'].toString())
          : null,
      isTermsConsentActive: map['terms_consent_active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'organization_name': organizationName,
      'phone': phone,
      'operating_location': operatingLocation,
      'is_verified': isVerified,
      'terms_consent_active': isTermsConsentActive,
      if (termsAcceptedVersion != null)
        'terms_accepted_version': termsAcceptedVersion,
      if (termsAcceptedAt != null)
        'terms_accepted_at': termsAcceptedAt!.toIso8601String(),
    };
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;
  User? get currentUser => SupabaseService.currentUser;
  bool get isAuthenticated => SupabaseService.isAuthenticated;

  /// Fetch profile for the current authenticated user by UUID
  Future<UserProfile?> fetchProfile({bool forceRefresh = false}) async {
    if (!SupabaseService.isInitialized) return null;
    final user = currentUser;
    if (user == null) {
      _currentProfile = null;
      notifyListeners();
      return null;
    }

    if (!forceRefresh && _currentProfile != null && _currentProfile!.id == user.id) {
      return _currentProfile;
    }

    try {
      // 0. First check user metadata and volunteers table for true role
      final meta = user.userMetadata ?? {};
      final metaRole = meta['role']?.toString().toLowerCase();

      Map<String, dynamic>? volRow;
      try {
        volRow = await SupabaseService.client
            .from('volunteers')
            .select('full_name, operating_location, phone')
            .eq('id', user.id)
            .maybeSingle();
        if (volRow == null && user.email != null && user.email!.isNotEmpty) {
          volRow = await SupabaseService.client
              .from('volunteers')
              .select('full_name, operating_location, phone')
              .ilike('email', user.email!.trim())
              .maybeSingle();
        }
      } catch (_) {}

      // 1. Query public.profiles using authenticated user UUID
      final row = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // If user is registered as volunteer (either in volunteers table or metadata), enforce and heal volunteer role
      if (volRow != null || metaRole == 'volunteer') {
        if (row == null || row['role'] != 'volunteer') {
          final healedProfile = {
            'id': user.id,
            'email': user.email ?? row?['email'] ?? '',
            'full_name': volRow?['full_name'] ?? row?['full_name'] ?? meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'Volunteer',
            'role': 'volunteer',
            'organization_name': 'Volunteer Squad',
            'operating_location': volRow?['operating_location'] ?? row?['operating_location'] ?? meta['operating_location'] ?? '',
            'phone': volRow?['phone'] ?? row?['phone'] ?? user.phone ?? meta['phone'] ?? '',
            'is_verified': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          try {
            await SupabaseService.client.from('profiles').upsert(healedProfile);
          } catch (_) {}
          _currentProfile = UserProfile.fromMap(healedProfile);
          notifyListeners();
          return _currentProfile;
        }
      }

      if (row != null && row['role'] != null && row['role'].toString().isNotEmpty) {
        _currentProfile = UserProfile.fromMap(row);
        notifyListeners();
        return _currentProfile;
      }

      // 2. Fallback check: If profile row is missing, check providers, receivers, or volunteers table by user_id
      String inferredRole = 'provider';
      String? orgName;
      String? fullName;

      final prov = await SupabaseService.client
          .from('providers')
          .select('organization_name, contact_person')
          .eq('user_id', user.id)
          .maybeSingle();

      if (prov != null) {
        inferredRole = 'provider';
        orgName = prov['organization_name']?.toString();
        fullName = prov['contact_person']?.toString();
      } else {
        final rec = await SupabaseService.client
            .from('receivers')
            .select('organization_name, authorized_representative')
            .eq('user_id', user.id)
            .maybeSingle();

        if (rec != null) {
          inferredRole = 'receiver';
          orgName = rec['organization_name']?.toString();
          fullName = rec['authorized_representative']?.toString();
        } else {
          if (volRow != null) {
            inferredRole = 'volunteer';
            fullName = volRow['full_name']?.toString();
            orgName = 'Volunteer Squad';
          } else {
            if (metaRole == 'receiver') {
              inferredRole = 'receiver';
            } else if (metaRole == 'volunteer') {
              inferredRole = 'volunteer';
            } else {
              inferredRole = 'provider';
            }
            orgName = meta['organization_name']?.toString() ?? (inferredRole == 'volunteer' ? 'Volunteer Squad' : null);
            fullName = meta['full_name']?.toString() ?? meta['name']?.toString();
          }
        }
      }

      // Automatically heal and create the missing profile row
      final autoProfile = {
        'id': user.id,
        'email': user.email ?? '',
        'full_name': fullName ?? orgName ?? user.email?.split('@').first ?? 'User',
        'role': inferredRole,
        'organization_name': orgName ?? user.email?.split('@').first ?? 'Organization',
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await SupabaseService.client.from('profiles').upsert(autoProfile);
      _currentProfile = UserProfile.fromMap(autoProfile);
      notifyListeners();
      return _currentProfile;
    } catch (e) {
      debugPrint('AuthService fetchProfile error: $e');
      return _currentProfile;
    }
  }

  /// Sign In with Email & Password (NEVER requires or takes a role)
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) throw Exception('Email cannot be empty.');
    if (password.isEmpty) throw Exception('Password cannot be empty.');

    // 1. Authenticate with Supabase Auth
    final res = await SupabaseService.client.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );

    final user = res.user;
    if (user == null) {
      throw Exception('Sign in succeeded but user session could not be established.');
    }

    // 2. Fetch profile from database using authenticated user UUID
    final profile = await fetchProfile(forceRefresh: true);
    if (profile == null) {
      throw Exception('User profile not found in database. Please contact support.');
    }

    return profile;
  }

  /// Verify Email OTP (NEVER requires or takes a role on login)
  Future<UserProfile> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();

    final res = await SupabaseService.client.auth.verifyOTP(
      email: cleanEmail,
      token: cleanToken,
      type: OtpType.email,
    );

    final user = res.user;
    if (user == null) {
      throw Exception('OTP verification succeeded but user session was not found.');
    }

    final profile = await fetchProfile(forceRefresh: true);
    if (profile == null) {
      throw Exception('Profile lookup failed after OTP verification.');
    }

    return profile;
  }

  /// Register as a Provider (Explicitly saves role='provider')
  Future<UserProfile> signUpProvider({
    required String email,
    required String password,
    required String organizationName,
    required String category,
    required String authorizedRepresentative,
    required String operatingLocation,
    String? phone,
  }) async {
    final cleanEmail = email.trim();
    final cleanOrg = organizationName.trim();
    final cleanRep = authorizedRepresentative.trim();
    final cleanLoc = operatingLocation.trim();

    // 1. Register with Supabase Auth
    AuthResponse authRes;
    try {
      authRes = await SupabaseService.client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'role': 'provider',
          'organization_name': cleanOrg,
          'authorized_representative': cleanRep,
          'full_name': cleanRep,
          'operating_location': cleanLoc,
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        },
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        authRes = await SupabaseService.client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final user = authRes.user ?? SupabaseService.currentUser;
    if (user == null) {
      throw Exception('Account created. Please check your email to confirm registration.');
    }

    // 2. Write profile with strict role='provider'
    final profileData = {
      'id': user.id,
      'email': cleanEmail,
      'full_name': cleanRep,
      'role': 'provider',
      'organization_name': cleanOrg,
      'operating_location': cleanLoc,
      'phone': phone?.trim(),
      'is_verified': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await SupabaseService.client.from('profiles').upsert(profileData);

    // 3. Write provider role table record with id = user.id
    try {
      await SupabaseService.client.from('providers').upsert({
        'id': user.id,
        'user_id': user.id,
        'organization_name': cleanOrg,
        'authorized_representative': cleanRep,
        'contact_person': cleanRep,
        'category': category,
        'operating_location': cleanLoc,
        'verification_method': 'auth',
        'is_verified': true,
      });
    } catch (e) {
      debugPrint('providers table insert notice: $e');
    }

    // 4. Verify profile was written
    final verifiedProfile = await fetchProfile(forceRefresh: true);
    if (verifiedProfile == null || verifiedProfile.role != 'provider') {
      throw Exception('Failed to verify Provider profile in database.');
    }

    return verifiedProfile;
  }

  /// Register as a Receiver / NGO (Explicitly saves role='receiver')
  Future<UserProfile> signUpReceiver({
    required String email,
    required String password,
    required String organizationName,
    required String category,
    required String dailyIntakeCapacity,
    required String representative,
    String? operatingLocation,
    String? phone,
  }) async {
    final cleanEmail = email.trim();
    final cleanOrg = organizationName.trim();
    final cleanRep = representative.trim();
    final cleanLoc = (operatingLocation != null && operatingLocation.trim().isNotEmpty)
        ? operatingLocation.trim()
        : 'Bengaluru, India';

    // 1. Register with Supabase Auth
    AuthResponse authRes;
    try {
      authRes = await SupabaseService.client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'role': 'receiver',
          'organization_name': cleanOrg,
          'authorized_representative': cleanRep,
          'full_name': cleanRep,
          'operating_location': cleanLoc,
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        },
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        authRes = await SupabaseService.client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final user = authRes.user ?? SupabaseService.currentUser;
    if (user == null) {
      throw Exception('Account created. Please check your email to confirm registration.');
    }

    // 2. Write profile with strict role='receiver'
    final profileData = {
      'id': user.id,
      'email': cleanEmail,
      'full_name': cleanRep,
      'role': 'receiver',
      'organization_name': cleanOrg,
      'operating_location': cleanLoc,
      'phone': phone?.trim(),
      'is_verified': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await SupabaseService.client.from('profiles').upsert(profileData);

    // 3. Write receiver role table record with id = user.id
    try {
      await SupabaseService.client.from('receivers').upsert({
        'id': user.id,
        'user_id': user.id,
        'organization_name': cleanOrg,
        'authorized_representative': cleanRep,
        'contact_person': cleanRep,
        'category': category,
        'daily_intake_capacity': dailyIntakeCapacity,
        'operating_location': cleanLoc,
        'verification_method': 'auth',
        'is_verified': true,
      });
    } catch (e) {
      debugPrint('receivers table insert notice: $e');
    }

    // 4. Verify profile was written
    final verifiedProfile = await fetchProfile(forceRefresh: true);
    if (verifiedProfile == null || verifiedProfile.role != 'receiver') {
      throw Exception('Failed to verify Receiver profile in database.');
    }

    return verifiedProfile;
  }

  /// Sign Out and completely clear cached profile and session state
  Future<void> signOut() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      debugPrint('SignOut notice: $e');
    }
    _currentProfile = null;
    notifyListeners();
  }
}
