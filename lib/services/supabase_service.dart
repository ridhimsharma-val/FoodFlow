import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_service.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://rowjcupaeerzcqsmbvsj.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_cRKg68Qasbkr0d4-1CYmJA_NdB7Fm2e';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
      ),
    );
  }

  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser {
    if (!isInitialized) return null;
    return client.auth.currentUser;
  }

  static bool get isAuthenticated => currentUser != null;

  /// Send 6-digit OTP code to Email
  static Future<void> sendEmailOtp({required String email}) async {
    await client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Verify 6-digit OTP code with Supabase
  static Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  /// Known test numbers and their custom OTPs for rapid offline/dev testing
  static const Map<String, String> customPhoneOtps = {
    '9555651225': '123456',
    '+919555651225': '123456',
    '9876543210': '123456',
    '+919876543210': '123456',
  };

  /// Check if phone number has a custom test OTP configured
  static String? getCustomOtpForPhone(String phone) {
    final clean = phone.trim().replaceAll(RegExp(r'\s+'), '');
    final withoutPlus91 = clean.replaceFirst(RegExp(r'^\+91'), '');
    return customPhoneOtps[clean] ?? customPhoneOtps[withoutPlus91];
  }

  /// Send 6-digit SMS OTP via Phone (triggers SMSLocal hook or custom test OTP)
  static Future<void> sendPhoneOtp({required String phone}) async {
    final clean = phone.trim().replaceAll(RegExp(r'\s+'), '');
    final formatted = clean.startsWith('+') ? clean : '+91$clean';
    try {
      await client.auth.signInWithOtp(
        phone: formatted,
        shouldCreateUser: true,
      );
    } catch (e) {
      // If phone is a custom test number (e.g. 9555651225), allow proceeding even if gateway fails
      if (getCustomOtpForPhone(phone) != null) {
        debugPrint('Using custom test OTP for $phone: ${getCustomOtpForPhone(phone)}');
        return;
      }
      rethrow;
    }
  }

  /// Verify 6-digit SMS OTP via Phone
  static Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final clean = phone.trim().replaceAll(RegExp(r'\s+'), '');
    final formatted = clean.startsWith('+') ? clean : '+91$clean';
    final customOtp = getCustomOtpForPhone(phone);

    try {
      return await client.auth.verifyOTP(
        phone: formatted,
        token: token.trim(),
        type: OtpType.sms,
      );
    } catch (e) {
      // If user entered the custom test OTP (e.g. 123456 for 9555651225), fallback to seamless auth
      if (customOtp != null && token.trim() == customOtp) {
        final email = 'phone_${clean.replaceFirst(RegExp(r'^\+91'), '')}@foodflow.org';
        return await signUpOrSignIn(email: email, password: 'FoodFlow@2025');
      }
      rethrow;
    }
  }

  /// Sign In with Email and Password (fallback)
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign Up with Email and Password (fallback)
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign Out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }


  /// Fetch user profile from public.profiles
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Fetch user profile by email from public.profiles
  static Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    if (!isInitialized) return null;
    try {
      final response = await client
          .from('profiles')
          .select()
          .ilike('email', email.trim())
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('getProfileByEmail notice: $e');
      return null;
    }
  }

  /// Check if an email is already registered across Supabase (RPC, profiles, providers, receivers, volunteers)
  static Future<Map<String, dynamic>?> checkEmailRegistered(String email) async {
    if (!isInitialized) return null;
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Try RPC check_email_registered (checks confirmed roles in profiles/providers/receivers/volunteers)
    try {
      final res = await client.rpc('check_email_registered', params: {'check_email': clean});
      if (res != null && res is Map && res['exists'] == true) {
        final role = res['role']?.toString();
        if (role != null && role.isNotEmpty && role != 'registered') {
          return {
            'exists': true,
            'role': role,
            'email': clean,
          };
        }
      }
    } catch (_) {
      // RPC may not be created in DB yet, fallback to table queries
    }

    // 2. Check public.profiles for an active role
    try {
      final profile = await client
          .from('profiles')
          .select('id, email, role, full_name')
          .ilike('email', clean)
          .maybeSingle();
      if (profile != null && profile['role'] != null && profile['role'].toString().isNotEmpty) {
        return {
          'exists': true,
          'role': profile['role'].toString(),
          'email': clean,
          'profile': profile,
        };
      }
    } catch (e) {
      debugPrint('Check profiles notice: $e');
    }

    // 3. Check public.providers (contact_email)
    try {
      final provider = await client
          .from('providers')
          .select('id, contact_email, organization_name')
          .ilike('contact_email', clean)
          .maybeSingle();
      if (provider != null) {
        return {
          'exists': true,
          'role': 'provider',
          'email': clean,
          'organization_name': provider['organization_name'],
        };
      }
    } catch (_) {}

    // 4. Check public.receivers (contact_email)
    try {
      final receiver = await client
          .from('receivers')
          .select('id, contact_email, organization_name')
          .ilike('contact_email', clean)
          .maybeSingle();
      if (receiver != null) {
        return {
          'exists': true,
          'role': 'receiver',
          'email': clean,
          'organization_name': receiver['organization_name'],
        };
      }
    } catch (_) {}

    // 5. Check public.volunteers (email)
    try {
      final volunteer = await client
          .from('volunteers')
          .select('id, email, full_name')
          .ilike('email', clean)
          .maybeSingle();
      if (volunteer != null) {
        return {
          'exists': true,
          'role': 'volunteer',
          'email': clean,
          'full_name': volunteer['full_name'],
        };
      }
    } catch (_) {}

    return null;
  }

  /// Enforce strict single-role exclusivity: 1 email = 1 account & 1 role
  static Future<String> resolveUserRole({
    required String email,
    required String fallbackRole,
  }) async {
    final clean = email.trim().toLowerCase();
    final user = currentUser;

    // 0. Check Supabase auth metadata first (highest source of truth from registration)
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final metaRole = meta['role']?.toString().toLowerCase();
      if (metaRole == 'volunteer') return 'volunteer';
      if (metaRole == 'receiver') return 'receiver';
    }

    // 1. Check volunteers table directly by UUID or email
    try {
      if (user != null) {
        final vol = await client.from('volunteers').select('id').eq('id', user.id).maybeSingle();
        if (vol != null) return 'volunteer';
      }
      if (clean.isNotEmpty) {
        final vol = await client.from('volunteers').select('id').ilike('email', clean).maybeSingle();
        if (vol != null) return 'volunteer';
      }
    } catch (_) {}

    // 2. Check receivers table directly by UUID or email
    try {
      if (user != null) {
        final rec = await client.from('receivers').select('id').eq('id', user.id).maybeSingle();
        if (rec != null) return 'receiver';
      }
      if (clean.isNotEmpty) {
        final rec = await client.from('receivers').select('id').ilike('email', clean).maybeSingle();
        if (rec != null) return 'receiver';
      }
    } catch (_) {}

    // 3. Check public.profiles
    if (user != null) {
      final profile = await getProfile(user.id);
      if (profile != null && profile['role'] != null) {
        final r = profile['role'].toString().toLowerCase();
        if (r == 'volunteer' || r == 'receiver' || r == 'provider') return r;
      }
    }
    if (clean.isNotEmpty) {
      final profile = await getProfileByEmail(clean);
      if (profile != null && profile['role'] != null) {
        final r = profile['role'].toString().toLowerCase();
        if (r == 'volunteer' || r == 'receiver' || r == 'provider') return r;
      }
    }

    // 4. Fallback check for providers table
    try {
      if (clean.isNotEmpty) {
        final prov = await client.from('providers').select('id').ilike('email', clean).maybeSingle();
        if (prov != null) return 'provider';
      }
    } catch (_) {}

    return fallbackRole.toLowerCase();
  }

  /// Ensure a provider row exists in public.providers and returns its UUID id (matches auth.users.id)
  static Future<String?> ensureProviderId(User user, {String? defaultOrgName}) async {
    if (!isInitialized) return null;
    try {
      final meta = user.userMetadata ?? {};
      final rep = (meta['authorized_representative'] != null && meta['authorized_representative'].toString().trim().isNotEmpty)
          ? meta['authorized_representative'].toString().trim()
          : (meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? '');

      final org = (defaultOrgName != null && defaultOrgName.isNotEmpty && defaultOrgName != 'FoodFlow Partner')
          ? defaultOrgName
          : ((meta['organization_name'] != null && meta['organization_name'].toString().isNotEmpty && meta['organization_name'] != 'FoodFlow Partner')
              ? meta['organization_name'].toString()
              : (rep.isNotEmpty ? rep : (user.email?.split('@').first ?? '')));

      final loc = LocationService.currentProviderLocation?.formattedAddress ??
          meta['operating_location'] ??
          '';

      final inserted = await client.from('providers').upsert({
        'id': user.id,
        'user_id': user.id,
        'email': user.email,
        'organization_name': org,
        'authorized_representative': rep,
        'contact_person': rep,
        'category': meta['category'] ?? 'Restaurant / Hotel',
        'operating_location': loc,
        'verification_method': 'auth',
        'phone': user.phone ?? meta['phone'] ?? '',
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();
      return inserted['id'].toString();
    } catch (e) {
      debugPrint('ensureProviderId notice: $e');
      return user.id;
    }
  }

  /// Ensure a receiver row exists in public.receivers and returns its UUID id (matches auth.users.id)
  static Future<String?> ensureReceiverId(User user, {String? defaultOrgName}) async {
    if (!isInitialized) return null;
    try {
      final meta = user.userMetadata ?? {};
      final rep = (meta['authorized_representative'] != null && meta['authorized_representative'].toString().trim().isNotEmpty)
          ? meta['authorized_representative'].toString().trim()
          : (meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? '');

      final org = (defaultOrgName != null && defaultOrgName.isNotEmpty && defaultOrgName != 'FoodFlow Partner')
          ? defaultOrgName
          : ((meta['organization_name'] != null && meta['organization_name'].toString().isNotEmpty && meta['organization_name'] != 'FoodFlow Partner')
              ? meta['organization_name'].toString()
              : (rep.isNotEmpty ? rep : (user.email?.split('@').first ?? '')));

      final loc = LocationService.currentProviderLocation?.formattedAddress ??
          meta['operating_location'] ??
          '';

      final inserted = await client.from('receivers').upsert({
        'id': user.id,
        'user_id': user.id,
        'email': user.email,
        'organization_name': org,
        'authorized_representative': rep,
        'category': meta['category'] ?? 'Charitable Shelter / Food Bank',
        'daily_intake_capacity': meta['daily_intake_capacity'] ?? '100+ Meals',
        'operating_location': loc,
        'phone': user.phone ?? meta['phone'] ?? '',
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();
      return inserted['id'].toString();
    } catch (e) {
      debugPrint('ensureReceiverId notice: $e');
      return user.id;
    }
  }

  /// Ensure a volunteer row exists in public.volunteers and returns its UUID id
  static Future<String?> ensureVolunteerId(User user, {String? defaultName}) async {
    if (!isInitialized) return null;
    try {
      final meta = user.userMetadata ?? {};
      final name = defaultName ?? meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? '';
      final loc = LocationService.currentProviderLocation?.formattedAddress ??
          meta['operating_location'] ??
          '';

      final inserted = await client.from('volunteers').upsert({
        'id': user.id,
        'user_id': user.id,
        'email': user.email,
        'full_name': name,
        'government_id': 'VERIFIED-VOL',
        'transit_mode': meta['transit_mode'] ?? 'Two-Wheeler',
        'operating_location': loc,
        'phone': user.phone ?? meta['phone'] ?? '',
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();
      return inserted['id'].toString();
    } catch (e) {
      debugPrint('ensureVolunteerId notice: $e');
      return user.id;
    }
  }

  /// Sync user profile on login with role preservation
  static Future<Map<String, dynamic>?> syncUserProfile([
    User? user,
    String? intendedRole,
  ]) async {
    final currentUser = user ?? client.auth.currentUser;
    if (currentUser == null) return null;

    try {
      final meta = currentUser.userMetadata ?? {};
      final fullName = meta['full_name'] ??
          meta['name'] ??
          currentUser.email?.split('@').first ??
          '';
      final avatarUrl = meta['avatar_url'] ?? meta['picture'] ?? '';
      final email = currentUser.email ?? '';

      // Check existing profile and role
      final existing = await getProfile(currentUser.id);
      final metaRole = meta['role']?.toString().toLowerCase();
      final role = (intendedRole != null && intendedRole.isNotEmpty)
          ? intendedRole
          : (metaRole == 'volunteer'
              ? 'volunteer'
              : (metaRole == 'receiver' ? 'receiver' : (existing?['role'] ?? 'provider')));

      final sessionLoc = LocationService.currentProviderLocation?.formattedAddress ??
          (existing?['operating_location'] != null && existing!['operating_location'].toString().trim().isNotEmpty
              ? existing['operating_location'].toString().trim()
              : (meta['operating_location'] ?? ''));

      final orgName = (meta['organization_name'] != null && meta['organization_name'].toString().trim().isNotEmpty)
          ? meta['organization_name'].toString().trim()
          : ((existing?['organization_name'] != null && existing!['organization_name'].toString().trim().isNotEmpty && existing['organization_name'] != 'FoodFlow Partner')
              ? existing['organization_name'].toString().trim()
              : fullName);

      final phone = currentUser.phone ?? meta['phone'] ?? existing?['phone'] ?? '';

      final profileData = {
        'id': currentUser.id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'role': role,
        'organization_name': orgName,
        'operating_location': sessionLoc,
        'phone': phone,
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await client.from('profiles').upsert(profileData);

      // Automatically ensure corresponding role table records and enforce strict single-role (no dual roles)
      if (role == 'provider') {
        await ensureProviderId(currentUser, defaultOrgName: orgName);
        try {
          await client.from('receivers').delete().eq('id', currentUser.id);
          await client.from('volunteers').delete().eq('id', currentUser.id);
        } catch (_) {}
      } else if (role == 'receiver') {
        await ensureReceiverId(currentUser, defaultOrgName: orgName);
        try {
          await client.from('providers').delete().eq('id', currentUser.id);
          await client.from('volunteers').delete().eq('id', currentUser.id);
        } catch (_) {}
      } else if (role == 'volunteer') {
        await ensureVolunteerId(currentUser, defaultName: fullName);
        try {
          await client.from('providers').delete().eq('id', currentUser.id);
          await client.from('receivers').delete().eq('id', currentUser.id);
        } catch (_) {}
      }

      return profileData;
    } catch (e) {
      debugPrint('syncUserProfile error: $e');
      return null;
    }
  }

  /// Sign Up or Sign In seamlessly (handles existing accounts gracefully)
  static Future<AuthResponse> signUpOrSignIn({
    required String email,
    required String password,
  }) async {
    try {
      return await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already exists')) {
        return await client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      }
      rethrow;
    }
  }

  /// Register Provider Profile & Data
  static Future<bool> createProvider({
    required String userId,
    required String email,
    required String organizationName,
    required String category,
    required String authorizedRepresentative,
    String? contactPerson,
    required String operatingLocation,
    String? fssaiLicenseNumber,
  }) async {
    final repName = authorizedRepresentative.trim().isNotEmpty
        ? authorizedRepresentative.trim()
        : (contactPerson?.trim() ?? '');

    try {
      // 0. Enforce strict single-role exclusivity
      final existing = await getProfile(userId);
      if (existing != null && existing['role'] != null) {
        final currentRole = existing['role'].toString().toLowerCase();
        if (currentRole != 'provider') {
          throw Exception(
            'This account is already registered as a ${currentRole == 'receiver' ? 'Relief NGO' : 'Volunteer Courier'}. '
            'Under FoodFlow compliance, an email cannot be both Provider and NGO at the same time. '
            'Please sign in with your food facility email or contact support.',
          );
        }
      }

      // 1. Create Base Profile with distinct organization_name and full_name (authorized representative)
      try {
        await client.from('profiles').upsert({
          'id': userId,
          'role': 'provider',
          'full_name': repName,
          'organization_name': organizationName.trim(),
          'email': email.trim(),
          if (fssaiLicenseNumber != null && fssaiLicenseNumber.isNotEmpty)
            'fssai_license_number': fssaiLicenseNumber.trim(),
          'is_verified': true,
        });
      } catch (_) {
        await client.from('profiles').upsert({
          'id': userId,
          'role': 'provider',
          'full_name': repName,
          'email': email.trim(),
          'is_verified': true,
        });
      }

      // 2. Create Provider Record with separate authorized_representative and organization_name columns
      try {
        await client.from('providers').upsert({
          'id': userId,
          'user_id': userId,
          'organization_name': organizationName.trim(),
          'authorized_representative': repName,
          'category': category,
          'contact_person': repName,
          'operating_location': operatingLocation.trim(),
          if (fssaiLicenseNumber != null && fssaiLicenseNumber.isNotEmpty)
            'fssai_license_number': fssaiLicenseNumber.trim(),
          'verification_method': 'email',
          'is_verified': true,
        });
      } catch (e) {
        // Fallback if authorized_representative column hasn't been added to table yet
        await client.from('providers').upsert({
          'id': userId,
          'user_id': userId,
          'organization_name': organizationName.trim(),
          'category': category,
          'contact_person': repName,
          'operating_location': operatingLocation.trim(),
          'verification_method': 'email',
          'is_verified': true,
        });
      }
      return true;
    } catch (e) {
      debugPrint('createProvider error: $e');
      rethrow;
    }
  }

  /// Register Receiver Profile & Data
  static Future<bool> createReceiver({
    required String userId,
    required String email,
    required String organizationName,
    required String category,
    required String dailyIntakeCapacity,
    required String representative,
  }) async {
    try {
      // 0. Enforce strict single-role exclusivity
      final existing = await getProfile(userId);
      if (existing != null && existing['role'] != null) {
        final currentRole = existing['role'].toString().toLowerCase();
        if (currentRole != 'receiver') {
          throw Exception(
            'This account is already registered as a ${currentRole == 'provider' ? 'Food Provider' : 'Volunteer Courier'}. '
            'Under FoodFlow compliance, an email cannot be both Provider and NGO at the same time. '
            'Please sign in with your NGO organization email or contact support.',
          );
        }
      }

      // 1. Create Base Profile
      await client.from('profiles').upsert({
        'id': userId,
        'role': 'receiver',
        'full_name': representative,
        'email': email.trim(),
        'organization_name': organizationName.trim(),
        'is_verified': true,
      });

      // 2. Create Receiver Record
      await client.from('receivers').upsert({
        'id': userId,
        'user_id': userId,
        'organization_name': organizationName.trim(),
        'category': category,
        'daily_intake_capacity': dailyIntakeCapacity,
        'authorized_representative': representative,
        'contact_person': representative,
        'is_verified': true,
      });
      return true;
    } catch (e) {
      debugPrint('createReceiver error: $e');
      rethrow;
    }
  }

  /// Register Volunteer Profile & Data
  static Future<bool> createVolunteer({
    required String userId,
    required String email,
    required String fullName,
    required String governmentId,
    required String transitMode,
    required String phone,
    String? operatingLocation,
  }) async {
    try {
      // 0. Enforce strict single-role exclusivity
      final existing = await getProfile(userId);
      if (existing != null && existing['role'] != null) {
        final currentRole = existing['role'].toString().toLowerCase();
        if (currentRole != 'volunteer') {
          throw Exception(
            'This account is already registered as a ${currentRole == 'provider' ? 'Food Provider' : 'Relief NGO'}. '
            'Please use a dedicated personal email for volunteer rescue operations.',
          );
        }
      }

      final loc = operatingLocation?.trim().isNotEmpty == true
          ? operatingLocation!.trim()
          : (LocationService.currentProviderLocation?.formattedAddress ?? 'Koramangala, Bengaluru');

      // 1. Create Base Profile
      await client.from('profiles').upsert({
        'id': userId,
        'role': 'volunteer',
        'full_name': fullName,
        'email': email.trim(),
        'phone': phone,
        'operating_location': loc,
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Create / Upsert Volunteer Record
      await client.from('volunteers').upsert({
        'id': userId,
        'user_id': userId,
        'email': email.trim(),
        'full_name': fullName,
        'government_id': governmentId,
        'transit_mode': transitMode,
        'operating_location': loc,
        'phone': phone,
        'is_active': true,
        'is_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 3. Sync Supabase Auth Metadata
      try {
        await client.auth.updateUser(UserAttributes(
          data: {
            'role': 'volunteer',
            'full_name': fullName,
            'name': fullName,
            'transit_mode': transitMode,
            'operating_location': loc,
            'phone': phone,
          },
        ));
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('createVolunteer error: $e');
      rethrow;
    }
  }

  /// Update user operating location and coordinates in Supabase
  static Future<void> updateUserLocation({
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    if (!isInitialized || currentUser == null) return;
    try {
      await client.auth.updateUser(UserAttributes(
        data: {
          'operating_location': locationName,
          'latitude': latitude,
          'longitude': longitude,
        },
      ));
      try {
        await client.from('providers').update({
          'operating_location': locationName,
        }).eq('user_id', currentUser!.id);
      } catch (_) {}
      try {
        await client.from('receivers').update({
          'operating_location': locationName,
        }).eq('user_id', currentUser!.id);
      } catch (_) {}
      try {
        await client.from('volunteers').update({
          'operating_location': locationName,
        }).eq('user_id', currentUser!.id);
      } catch (_) {}
      try {
        await client.from('profiles').update({
          'operating_location': locationName,
        }).eq('id', currentUser!.id);
      } catch (_) {}
    } catch (e) {
      debugPrint('updateUserLocation notice: $e');
    }
  }

  /// Update full user profile across Supabase Auth metadata, public.profiles,
  /// and the role-specific table (providers, receivers, volunteers).
  static Future<bool> updateUserProfile({
    required String fullName,
    required String organizationName,
    String? phone,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    if (!isInitialized || currentUser == null) return false;
    final user = currentUser!;
    final trimmedName = fullName.trim();
    final trimmedOrg = organizationName.trim();
    final trimmedPhone = phone?.trim();
    final trimmedLoc = location?.trim();

    // 1. Update Auth user metadata
    try {
      await client.auth.updateUser(UserAttributes(
        data: {
          'full_name': trimmedName,
          'name': trimmedName,
          'organization_name': trimmedOrg,
          'authorized_representative': trimmedName,
          'contact_person': trimmedName,
          if (trimmedPhone != null && trimmedPhone.isNotEmpty) 'phone': trimmedPhone,
          if (trimmedLoc != null && trimmedLoc.isNotEmpty) 'operating_location': trimmedLoc,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      ));
      debugPrint('Auth metadata updated: org=$trimmedOrg, name=$trimmedName');
    } catch (e) {
      debugPrint('updateUser auth metadata notice: $e');
    }

    // 2. Update public.profiles
    try {
      await client.from('profiles').update({
        'full_name': trimmedName,
        'organization_name': trimmedOrg,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      debugPrint('profiles updated with organization_name and full_name');
    } catch (_) {
      try {
        await client.from('profiles').update({
          'full_name': trimmedName,
        }).eq('id', user.id);
        debugPrint('profiles updated with full_name');
      } catch (e) {
        debugPrint('update profiles error: $e');
      }
    }

    // 3. Update public.providers (exact columns: organization_name, contact_person, operating_location, authorized_representative)
    try {
      final provUpdate = <String, dynamic>{
        'organization_name': trimmedOrg,
        'contact_person': trimmedName,
      };
      if (trimmedLoc != null && trimmedLoc.isNotEmpty) {
        provUpdate['operating_location'] = trimmedLoc;
      }

      bool updated = false;
      try {
        final withRep = Map<String, dynamic>.from(provUpdate);
        withRep['authorized_representative'] = trimmedName;
        final res = await client.from('providers').update(withRep).eq('user_id', user.id).select('id');
        if (res.isNotEmpty) {
          updated = true;
          debugPrint('providers table updated with authorized_representative: ${res.length} rows');
        }
      } catch (e) {
        debugPrint('providers update with authorized_representative error: $e. Retrying with base columns...');
      }

      if (!updated) {
        final res = await client.from('providers').update(provUpdate).eq('user_id', user.id).select('id');
        debugPrint('providers table updated with contact_person: ${res.length} rows');
      }
    } catch (e) {
      debugPrint('providers table update error: $e');
    }

    // 4. Update public.receivers
    try {
      final recUpdate = <String, dynamic>{
        'organization_name': trimmedOrg,
        'contact_person': trimmedName,
      };
      if (trimmedLoc != null && trimmedLoc.isNotEmpty) {
        recUpdate['operating_location'] = trimmedLoc;
      }

      bool updated = false;
      try {
        final withRep = Map<String, dynamic>.from(recUpdate);
        withRep['authorized_representative'] = trimmedName;
        final res = await client.from('receivers').update(withRep).eq('user_id', user.id).select('id');
        if (res.isNotEmpty) updated = true;
      } catch (_) {}

      if (!updated) {
        await client.from('receivers').update(recUpdate).eq('user_id', user.id);
      }
    } catch (e) {
      debugPrint('receivers table update error: $e');
    }

    // 5. Update public.volunteers
    try {
      final volUpdate = <String, dynamic>{
        'full_name': trimmedName,
      };
      if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
        volUpdate['phone'] = trimmedPhone;
      }
      if (trimmedLoc != null && trimmedLoc.isNotEmpty) {
        volUpdate['operating_location'] = trimmedLoc;
      }
      await client.from('volunteers').update(volUpdate).eq('user_id', user.id);
    } catch (e) {
      debugPrint('volunteers table update error: $e');
    }

    return true;
  }
}
