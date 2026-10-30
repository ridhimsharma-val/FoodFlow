import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dynamic_pricing_service.dart';
import 'supabase_service.dart';

enum BatchStatus {
  available,
  claimed,
  volunteerAssigning,
  inTransitToPickup,
  arrivedAtPickup,
  pickedUp,
  inTransit,
  arrivedAtReceiver,
  delivered,
  expired,
  cancelled,
  reassigning,
}

class SurplusBatch {
  final String id;
  final String? providerId;
  final String providerName;
  final String providerCategory;
  final LatLng location;
  final String title;
  final String category;
  final int quantityPortions;
  final String dietaryType;
  final DateTime cookedAt;
  final DateTime safeUntil;
  final double temperatureCelsius;
  final String packagingType;
  final String pickupAddress;
  final String pickupOtp;
  final String deliveryOtp;

  // Static pricing inputs (compute-on-read model)
  final double basePrice;
  final double floorPrice;
  final String foodType;
  final String qualityTier;
  final bool clearKitchen;

  // Locked transaction fields (persisted upon NGO claim/purchase)
  double? lockedUnitPrice;
  double? lockedTotalPrice;
  double? discountAtPurchase;
  double? timeRemainingHoursAtPurchase;

  BatchStatus status;
  String? claimedByNgo;
  String? claimedByNgoId;
  String? assignedCourierId;
  String? assignedCourierName;
  String? assignedCourierPhone;
  String? receiverDropoffAddress;
  String? specialInstructions;
  int? courierEtaMinutes;
  double? distanceRemainingKm;
  double? courierCurrentLat;
  double? courierCurrentLng;
  double? courierHeading;
  DateTime? assigningStartedAt;
  DateTime? claimedAt;
  DateTime? pickedUpAt;
  DateTime? deliveredAt;

  SurplusBatch({
    required this.id,
    this.providerId,
    required this.providerName,
    required this.providerCategory,
    required this.location,
    required this.title,
    required this.category,
    required this.quantityPortions,
    required this.dietaryType,
    required this.cookedAt,
    required this.safeUntil,
    required this.temperatureCelsius,
    required this.packagingType,
    required this.pickupAddress,
    required this.pickupOtp,
    required this.deliveryOtp,
    this.basePrice = 50.0,
    this.floorPrice = 10.0,
    this.foodType = 'normal',
    this.qualityTier = 'tier1',
    this.clearKitchen = false,
    this.lockedUnitPrice,
    this.lockedTotalPrice,
    this.discountAtPurchase,
    this.timeRemainingHoursAtPurchase,
    this.status = BatchStatus.available,
    this.claimedByNgo,
    this.claimedByNgoId,
    this.assignedCourierId,
    this.assignedCourierName,
    this.assignedCourierPhone,
    this.receiverDropoffAddress,
    this.specialInstructions,
    this.courierEtaMinutes,
    this.distanceRemainingKm,
    this.courierCurrentLat,
    this.courierCurrentLng,
    this.courierHeading,
    this.assigningStartedAt,
    this.claimedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  LatLng get receiverCoordinates {
    return LatLng(
      location.latitude + 0.018,
      location.longitude + 0.014,
    );
  }

  LatLng get courierLocation {
    if (courierCurrentLat != null && courierCurrentLng != null) {
      return LatLng(courierCurrentLat!, courierCurrentLng!);
    }
    return LatLng(
      location.latitude - 0.009,
      location.longitude - 0.007,
    );
  }

  bool get isAssigning => status == BatchStatus.volunteerAssigning;

  bool get isAssigned =>
      status != BatchStatus.available &&
      status != BatchStatus.claimed &&
      status != BatchStatus.volunteerAssigning &&
      status != BatchStatus.expired &&
      status != BatchStatus.cancelled;

  bool get isPickedUp =>
      status == BatchStatus.pickedUp ||
      status == BatchStatus.inTransit ||
      status == BatchStatus.arrivedAtReceiver ||
      status == BatchStatus.delivered;

  bool get isDelivered => status == BatchStatus.delivered;

  Duration get remainingSafeTime {
    final diff = safeUntil.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => remainingSafeTime == Duration.zero;

  /// Dynamic Markdown Pricing result calculated on-read (or locked transaction result)
  DynamicPriceResult get dynamicPricing {
    if (lockedUnitPrice != null) {
      final double unit = lockedUnitPrice!;
      final double total = lockedTotalPrice ?? (unit * quantityPortions);
      final double base = basePrice;
      final double totalBase = base * quantityPortions;
      final double discount = discountAtPurchase ??
          (base > 0 ? ((base - unit) / base) * 100.0 : 0.0);
      return DynamicPriceResult(
        currentPrice: unit,
        totalPrice: total,
        basePrice: base,
        totalBasePrice: totalBase,
        floorPrice: floorPrice,
        discountPercentage: discount,
        youSave: math.max(0.0, totalBase - total),
        timeRemaining: remainingSafeTime,
        timeRemainingHours: timeRemainingHoursAtPurchase ?? (remainingSafeTime.inSeconds / 3600.0),
        qualityMultiplier: DynamicPricingService.config.getQualityMultiplier(QualityTier.fromString(qualityTier)),
        quantityMultiplier: DynamicPricingService.config.getQuantityMultiplier(quantity: quantityPortions, clearKitchen: clearKitchen),
        perishabilityFactor: DynamicPricingService.config.getGammaForFoodType(FoodType.fromString(foodType)),
        decayFactor: 1.0,
        isExpired: isExpired,
      );
    }

    return DynamicPricingService.calculateDynamicPrice(
      basePrice: basePrice,
      floorPrice: floorPrice,
      quantity: quantityPortions,
      safeUntil: safeUntil,
      cookedAt: cookedAt,
      foodType: FoodType.fromString(foodType),
      qualityTier: QualityTier.fromString(qualityTier),
      clearKitchen: clearKitchen,
    );
  }

  static bool isValidUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value);
  }
  static bool _isValidUuid(String value) => isValidUuid(value);

  Map<String, dynamic> toJson({bool includePricing = true}) {
    String normalizedDietary = dietaryType;
    if (normalizedDietary == 'Vegetarian' || normalizedDietary.isEmpty) {
      normalizedDietary = 'Pure Veg';
    }

    final data = <String, dynamic>{
      'id': id,
      if (providerId != null && _isValidUuid(providerId!)) 'provider_id': providerId,
      'provider_name': providerName,
      'provider_category': providerCategory,
      'title': title,
      'category': category,
      'quantity_portions': quantityPortions,
      'dietary_type': normalizedDietary,
      'cooked_at': cookedAt.toUtc().toIso8601String(),
      'safe_until': safeUntil.toUtc().toIso8601String(),
      'temperature_celsius': temperatureCelsius,
      'packaging_type': packagingType,
      'pickup_address': pickupAddress,
      'pickup_latitude': location.latitude,
      'pickup_longitude': location.longitude,
      'pickup_otp': pickupOtp,
      'delivery_otp': deliveryOtp,
      'status': status.name,
      'claimed_by_ngo_name': claimedByNgo,
      if (claimedByNgoId != null && _isValidUuid(claimedByNgoId!)) 'claimed_by_ngo_id': claimedByNgoId,
      if (assignedCourierId != null && _isValidUuid(assignedCourierId!)) 'assigned_courier_id': assignedCourierId,
      'assigned_courier_name': assignedCourierName,
      'assigned_courier_phone': assignedCourierPhone,
      if (receiverDropoffAddress != null) 'receiver_dropoff_address': receiverDropoffAddress,
      if (specialInstructions != null) 'special_instructions': specialInstructions,
      'courier_eta_minutes': courierEtaMinutes,
      if (distanceRemainingKm != null) 'distance_remaining_km': distanceRemainingKm,
      if (courierCurrentLat != null) 'courier_latitude': courierCurrentLat,
      if (courierCurrentLng != null) 'courier_longitude': courierCurrentLng,
      if (courierHeading != null) 'courier_heading': courierHeading,
      if (assigningStartedAt != null) 'assigning_started_at': assigningStartedAt?.toUtc().toIso8601String(),
      'claimed_at': claimedAt?.toUtc().toIso8601String(),
      'picked_up_at': pickedUpAt?.toUtc().toIso8601String(),
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
    };

    if (includePricing) {
      data['base_price'] = basePrice;
      data['floor_price'] = floorPrice;
      data['food_type'] = foodType;
      data['quality_tier'] = qualityTier;
      data['clear_kitchen'] = clearKitchen;
      if (lockedUnitPrice != null) data['locked_unit_price'] = lockedUnitPrice;
      if (lockedTotalPrice != null) data['locked_total_price'] = lockedTotalPrice;
      if (discountAtPurchase != null) data['discount_at_purchase'] = discountAtPurchase;
      if (timeRemainingHoursAtPurchase != null) {
        data['time_remaining_hours_at_purchase'] = timeRemainingHoursAtPurchase;
      }
    }

    return data;
  }

  static DateTime _parseDateTime(dynamic val, {int fallbackHours = 0}) {
    if (val == null) return DateTime.now().add(Duration(hours: fallbackHours));
    final str = val.toString();
    final dt = DateTime.tryParse(str);
    if (dt == null) return DateTime.now().add(Duration(hours: fallbackHours));

    var local = dt.toLocal();
    final now = DateTime.now();

    // Guard against timestamps stored with wall-clock time in UTC (+00:00)
    if (fallbackHours == 0 && local.isAfter(now.add(const Duration(minutes: 5)))) {
      local = local.subtract(now.timeZoneOffset);
    }
    return local;
  }

  static DateTime _parseSafeUntil(dynamic val, DateTime cookedAt, {int fallbackHours = 4}) {
    if (val == null) return cookedAt.add(Duration(hours: fallbackHours));
    final str = val.toString();
    final dt = DateTime.tryParse(str);
    if (dt == null) return cookedAt.add(Duration(hours: fallbackHours));

    var local = dt.toLocal();
    final now = DateTime.now();

    // Guard against timestamps stored with wall-clock time in UTC (+00:00)
    if (local.difference(cookedAt) > const Duration(hours: 8) ||
        local.difference(now) > const Duration(hours: 8)) {
      local = local.subtract(now.timeZoneOffset);
    }
    return local;
  }

  static SurplusBatch fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'available';
    final batchStatus = BatchStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => BatchStatus.available,
    );

    final lat = (json['pickup_latitude'] as num?)?.toDouble() ?? 12.9784;
    final lng = (json['pickup_longitude'] as num?)?.toDouble() ?? 77.6408;

    final parsedCooked = _parseDateTime(json['cooked_at']);
    final parsedSafe = _parseSafeUntil(json['safe_until'], parsedCooked);

    return SurplusBatch(
      id: json['id'] as String? ?? 'BATCH-${DateTime.now().millisecondsSinceEpoch}',
      providerId: json['provider_id'] as String?,
      providerName: json['provider_name'] as String? ?? 'Provider Kitchen',
      providerCategory: json['provider_category'] as String? ?? 'Commercial Kitchen',
      location: LatLng(lat, lng),
      title: json['title'] as String? ?? 'Surplus Meals',
      category: json['category'] as String? ?? 'Cooked Meals',
      quantityPortions: (json['quantity_portions'] as num?)?.toInt() ?? 1,
      dietaryType: json['dietary_type'] as String? ?? 'Vegetarian',
      cookedAt: parsedCooked,
      safeUntil: parsedSafe,
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble() ?? 65.0,
      packagingType: json['packaging_type'] as String? ?? 'Food-Grade Meal Boxes',
      pickupAddress: json['pickup_address'] as String? ?? '12th Main Road, Indiranagar, Bengaluru',
      pickupOtp: json['pickup_otp'] as String? ?? '4821',
      deliveryOtp: json['delivery_otp'] as String? ?? '7390',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 50.0,
      floorPrice: (json['floor_price'] as num?)?.toDouble() ?? 10.0,
      foodType: json['food_type'] as String? ?? 'normal',
      qualityTier: json['quality_tier'] as String? ?? 'tier1',
      clearKitchen: json['clear_kitchen'] as bool? ?? false,
      lockedUnitPrice: (json['locked_unit_price'] as num?)?.toDouble(),
      lockedTotalPrice: (json['locked_total_price'] as num?)?.toDouble(),
      discountAtPurchase: (json['discount_at_purchase'] as num?)?.toDouble(),
      timeRemainingHoursAtPurchase: (json['time_remaining_hours_at_purchase'] as num?)?.toDouble(),
      status: batchStatus,
      claimedByNgo: json['claimed_by_ngo_name'] as String?,
      claimedByNgoId: json['claimed_by_ngo_id'] as String?,
      assignedCourierId: json['assigned_courier_id'] as String?,
      assignedCourierName: json['assigned_courier_name'] as String?,
      assignedCourierPhone: json['assigned_courier_phone'] as String?,
      receiverDropoffAddress: json['receiver_dropoff_address'] as String? ??
          (json['claimed_by_ngo_name'] != null ? '${json['claimed_by_ngo_name']} Center, Greater Noida' : 'Helping Hands NGO, Greater Noida'),
      specialInstructions: json['special_instructions'] as String? ?? 'Handle with care. Thermal packaging required.',
      courierEtaMinutes: (json['courier_eta_minutes'] as num?)?.toInt(),
      distanceRemainingKm: (json['distance_remaining_km'] as num?)?.toDouble(),
      courierCurrentLat: (json['courier_latitude'] as num?)?.toDouble() ??
          (json['courier_current_lat'] as num?)?.toDouble(),
      courierCurrentLng: (json['courier_longitude'] as num?)?.toDouble() ??
          (json['courier_current_lng'] as num?)?.toDouble(),
      courierHeading: (json['courier_heading'] as num?)?.toDouble(),
      assigningStartedAt: json['assigning_started_at'] != null ? _parseDateTime(json['assigning_started_at']) : null,
      claimedAt: json['claimed_at'] != null ? _parseDateTime(json['claimed_at']) : null,
      pickedUpAt: json['picked_up_at'] != null ? _parseDateTime(json['picked_up_at']) : null,
      deliveredAt: json['delivered_at'] != null ? _parseDateTime(json['delivered_at']) : null,
    );
  }
}

class FoodRescueService extends ChangeNotifier {
  static final FoodRescueService instance = FoodRescueService._internal();

  factory FoodRescueService() => instance;

  FoodRescueService._internal() {
    _initSeedData();
    // Do not run background loop timer in automated unit/widget test environment
    bool isTest = false;
    try {
      isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      isTest = true;
    }
    if (!isTest) {
      startLivePricingTicker();
    }
  }

  final List<SurplusBatch> _batches = [];
  RealtimeChannel? _realtimeChannel;
  Timer? _syncPollTimer;
  Timer? _livePricingTimer;

  void startLivePricingTicker() {
    _livePricingTimer?.cancel();
    _livePricingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // If there are batches that need continuous countdown and pricing recalculation, tick
      if (_batches.any((b) => b.status != BatchStatus.delivered)) {
        for (final b in _batches) {
          if (b.status == BatchStatus.available && b.isExpired) {
            b.status = BatchStatus.expired;
          }
        }
        notifyListeners();
      }
    });
  }

  void stopLivePricingTicker() {
    _livePricingTimer?.cancel();
    _livePricingTimer = null;
  }

  List<SurplusBatch> get batches => List.unmodifiable(_batches);

  List<SurplusBatch> get availableBatches =>
      _batches.where((b) => b.status == BatchStatus.available && !b.isExpired).toList();

  List<SurplusBatch> get availableDeliveryTasks {
    return _batches.where((b) {
      final isClaimedPendingCourier = (b.status == BatchStatus.claimed || b.status == BatchStatus.reassigning) &&
          (b.assignedCourierId == null || b.assignedCourierId!.isEmpty);
      return isClaimedPendingCourier && !b.isExpired;
    }).toList();
  }

  List<SurplusBatch> get activeRescues =>
      _batches.where((b) =>
          b.status == BatchStatus.claimed ||
          b.status == BatchStatus.volunteerAssigning ||
          b.status == BatchStatus.inTransitToPickup ||
          b.status == BatchStatus.arrivedAtPickup ||
          b.status == BatchStatus.pickedUp ||
          b.status == BatchStatus.inTransit ||
          b.status == BatchStatus.arrivedAtReceiver).toList();

  /// Find active rescue for Provider (status is claimed, assigning, en route, picked up, or in transit)
  SurplusBatch? getActiveRescueForProvider(String providerName, {String? providerId}) {
    final cleanProvider = providerName.trim().toLowerCase();
    final currentUserId = providerId ?? SupabaseService.currentUser?.id;

    final activeList = _batches.where((b) =>
        b.status != BatchStatus.available &&
        b.status != BatchStatus.delivered &&
        b.status != BatchStatus.expired &&
        b.status != BatchStatus.cancelled).toList();

    if (activeList.isEmpty) return null;

    // 1. Specific match by provider ID or name
    final specific = activeList.cast<SurplusBatch?>().firstWhere(
      (b) {
        if (b == null) return false;
        final batchProvider = b.providerName.trim().toLowerCase();
        final isIdMatch = currentUserId != null && b.providerId != null && b.providerId == currentUserId;
        final isNameMatch = batchProvider == cleanProvider ||
            cleanProvider.contains(batchProvider) ||
            batchProvider.contains(cleanProvider) ||
            (cleanProvider.contains('grand palace') && batchProvider.contains('grand palace'));
        return isIdMatch || isNameMatch;
      },
      orElse: () => null,
    );

    if (specific != null) return specific;

    // 2. Demo fallback if user has generic default test name
    if (cleanProvider == 'abc restaurant' ||
        cleanProvider == 'food provider' ||
        cleanProvider == 'commercial kitchen' ||
        cleanProvider == 'foodflow partner' ||
        cleanProvider.isEmpty) {
      return activeList.first;
    }

    return null;
  }

  /// Find active rescue for Receiver (status is claimed, assigning, en route, picked up, or in transit)
  SurplusBatch? getActiveRescueForReceiver(String receiverOrg, {String? receiverId}) {
    final cleanOrg = receiverOrg.trim().toLowerCase();
    final currentUserId = receiverId ?? SupabaseService.currentUser?.id;

    final activeList = _batches.where((b) =>
        b.status != BatchStatus.available &&
        b.status != BatchStatus.delivered &&
        b.status != BatchStatus.expired &&
        b.status != BatchStatus.cancelled).toList();

    if (activeList.isEmpty) return null;

    // 1. Specific match by receiver ID or NGO name
    final specific = activeList.cast<SurplusBatch?>().firstWhere(
      (b) {
        if (b == null) return false;
        final batchOrg = (b.claimedByNgo ?? '').trim().toLowerCase();
        final isIdMatch = currentUserId != null && b.claimedByNgoId != null && b.claimedByNgoId == currentUserId;
        final isNameMatch = batchOrg.isNotEmpty &&
            (batchOrg == cleanOrg || cleanOrg.contains(batchOrg) || batchOrg.contains(cleanOrg));
        return isIdMatch || isNameMatch;
      },
      orElse: () => null,
    );

    if (specific != null) return specific;

    // 2. Demo fallback if user has generic default test name
    if (cleanOrg == 'helping hands ngo' ||
        cleanOrg == 'foodflow partner' ||
        cleanOrg.isEmpty) {
      return activeList.first;
    }

    return null;
  }

  List<SurplusBatch> get completedRescues =>
      _batches.where((b) => b.status == BatchStatus.delivered).toList();

  // Metrics
  int get totalMealsRescued =>
      _batches.where((b) => b.status == BatchStatus.delivered).fold(0, (sum, b) => sum + b.quantityPortions) + 1280;

  double get carbonDivertedKg => (totalMealsRescued * 1.85);

  String? lastFetchError;

  /// Filter batches for a specific provider
  List<SurplusBatch> getBatchesForProvider(String providerName, {bool todayOnly = true}) {
    final cleanProvider = providerName.trim().toLowerCase();
    final now = DateTime.now();
    final currentUserId = SupabaseService.currentUser?.id;

    return _batches.where((b) {
      if (b.id.startsWith('MOCK-')) return false;

      final batchProvider = b.providerName.trim().toLowerCase();
      bool belongs = false;
      if (currentUserId != null && b.providerId != null && b.providerId!.isNotEmpty) {
        belongs = (b.providerId == currentUserId);
      } else if (cleanProvider.isNotEmpty) {
        belongs = (batchProvider == cleanProvider ||
            batchProvider.contains(cleanProvider) ||
            cleanProvider.contains(batchProvider));
      }

      if (!belongs) return false;

      if (todayOnly) {
        final isSameDay = b.cookedAt.year == now.year &&
            b.cookedAt.month == now.month &&
            b.cookedAt.day == now.day;
        final isRecentlyActive = b.safeUntil.isAfter(now.subtract(const Duration(hours: 12)));
        return isSameDay || isRecentlyActive;
      }
      return true;
    }).toList();
  }

  void _initSeedData() {
    // Kept empty in production so only genuine Supabase listings are displayed
  }

  /// Initialize real-time sync with Supabase
  void initSupabaseSync([String? callerIdentifier]) {
    if (!SupabaseService.isInitialized) return;

    try {
      // 1. Fetch current listings from Supabase to merge
      SupabaseService.client
          .from('surplus_batches')
          .select()
          .order('created_at', ascending: false)
          .then((data) {
        if (data.isNotEmpty) {
          for (final row in data) {
            final batch = SurplusBatch.fromJson(row);
            final idx = _batches.indexWhere((b) => b.id == batch.id);
            if (idx >= 0) {
              _batches[idx] = batch;
            } else {
              _batches.insert(0, batch);
            }
          }
          notifyListeners();
        }
      }).catchError((err) {
        debugPrint('Supabase initial fetch notice: $err');
      });

      // 2. Realtime subscription on surplus_batches table (keep persistent)
      _realtimeChannel ??= SupabaseService.client
            .channel('public:surplus_batches_realtime')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'surplus_batches',
              callback: (payload) {
                if (payload.eventType == PostgresChangeEvent.delete) {
                  final oldRecord = payload.oldRecord;
                  final oldId = oldRecord['id'] as String?;
                  if (oldId != null) {
                    _batches.removeWhere((b) => b.id == oldId);
                    notifyListeners();
                  }
                  return;
                }

                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty) {
                  final batch = SurplusBatch.fromJson(newRecord);
                  debugPrint('[REALTIME_EVENT_RECEIVED] Event: ${payload.eventType}, Batch ID: ${batch.id}, Status: ${batch.status.name}, Courier: ${batch.assignedCourierName}');
                  final idx = _batches.indexWhere((b) => b.id == batch.id);
                  if (idx >= 0) {
                    _batches[idx] = batch;
                  } else {
                    _batches.insert(0, batch);
                  }
                  debugPrint('[PROVIDER_STATE_UPDATED] Provider active state synced for batch ${batch.id}');
                  debugPrint('[RECEIVER_STATE_UPDATED] Receiver active state synced for batch ${batch.id}');
                  notifyListeners();
                }
              },
            )
            .subscribe();

      // 3. Periodic background sync (every 2 seconds) for instant cross-tab parity
      _syncPollTimer?.cancel();
      _syncPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        refreshBatches();
      });
    } catch (e) {
      debugPrint('Supabase realtime init notice: $e');
    }
  }

  static bool _hasPricingColumns = true;

  /// Explicitly refresh batches from Supabase
  Future<void> refreshBatches() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final data = await SupabaseService.client
          .from('surplus_batches')
          .select()
          .order('created_at', ascending: false);
      lastFetchError = null;
      if (data.isNotEmpty) {
        bool changed = false;
        for (final row in data) {
          final batch = SurplusBatch.fromJson(row);
          final idx = _batches.indexWhere((b) => b.id == batch.id);
          if (idx >= 0) {
            if (_batches[idx].status != batch.status ||
                _batches[idx].claimedByNgo != batch.claimedByNgo ||
                _batches[idx].assignedCourierId != batch.assignedCourierId ||
                _batches[idx].assignedCourierName != batch.assignedCourierName) {
              _batches[idx] = batch;
              changed = true;
            }
          } else {
            _batches.insert(0, batch);
            changed = true;
          }
        }
        if (changed) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('refreshBatches notice: $e');
      lastFetchError = e.toString();
      notifyListeners();
    }
  }

  /// Resilient batch upsert: tries full schema first; falls back to base schema if pricing columns are missing
  Future<void> _syncBatchUpsert(SurplusBatch batch) async {
    if (!SupabaseService.isInitialized) return;

    if (_hasPricingColumns) {
      try {
        await SupabaseService.client.from('surplus_batches').upsert(batch.toJson(includePricing: true));
        debugPrint('Batch successfully synced to Supabase (full schema): ${batch.id}');
        return;
      } catch (err) {
        final errStr = err.toString();
        if (errStr.contains('PGRST204') || errStr.contains('base_price') || errStr.contains('column')) {
          debugPrint('Supabase surplus_batches schema lacks pricing columns. Falling back to base columns: $err');
          _hasPricingColumns = false;
        } else {
          debugPrint('Supabase insert notice: $err');
          return;
        }
      }
    }

    try {
      await SupabaseService.client.from('surplus_batches').upsert(batch.toJson(includePricing: false));
      debugPrint('Batch successfully synced to Supabase (base schema fallback): ${batch.id}');
    } catch (fallbackErr) {
      debugPrint('Supabase insert base fallback notice: $fallbackErr');
    }
  }

  /// Resilient batch update: tries full schema first; falls back to base schema if pricing columns are missing
  Future<void> _syncBatchUpdate(SurplusBatch batch, [Map<String, dynamic>? specificData]) async {
    if (!SupabaseService.isInitialized) return;

    if (specificData != null) {
      try {
        await SupabaseService.client.from('surplus_batches').update(specificData).eq('id', batch.id);
        debugPrint('Batch updated in Supabase: ${batch.id}');
        return;
      } catch (e) {
        debugPrint('Supabase specific update notice: $e');
        // Fallback: update core columns only
        try {
          final coreFallback = <String, dynamic>{
            'status': batch.status.name,
            if (batch.assignedCourierName != null) 'assigned_courier_name': batch.assignedCourierName,
            if (batch.assignedCourierPhone != null) 'assigned_courier_phone': batch.assignedCourierPhone,
            if (batch.courierEtaMinutes != null) 'courier_eta_minutes': batch.courierEtaMinutes,
            if (batch.claimedByNgo != null) 'claimed_by_ngo_name': batch.claimedByNgo,
          };
          await SupabaseService.client.from('surplus_batches').update(coreFallback).eq('id', batch.id);
          debugPrint('Batch updated in Supabase (core fallback): ${batch.id}');
          return;
        } catch (coreErr) {
          debugPrint('Supabase core update fallback notice: $coreErr');
        }
      }
    }

    if (_hasPricingColumns) {
      try {
        await SupabaseService.client.from('surplus_batches').update(batch.toJson(includePricing: true)).eq('id', batch.id);
        debugPrint('Batch updated in Supabase (full schema): ${batch.id}');
        return;
      } catch (err) {
        final errStr = err.toString();
        if (errStr.contains('PGRST204') || errStr.contains('base_price') || errStr.contains('column')) {
          _hasPricingColumns = false;
        } else {
          debugPrint('Supabase update notice: $err');
          return;
        }
      }
    }

    try {
      await SupabaseService.client.from('surplus_batches').update(batch.toJson(includePricing: false)).eq('id', batch.id);
      debugPrint('Batch updated in Supabase (base schema fallback): ${batch.id}');
    } catch (fallbackErr) {
      debugPrint('Supabase update base fallback notice: $fallbackErr');
    }
  }

  /// Provider lists a new surplus food batch
  SurplusBatch listNewBatch({
    required String providerName,
    required String providerCategory,
    required String title,
    required String category,
    required int quantityPortions,
    required String dietaryType,
    required double temperatureCelsius,
    required String packagingType,
    required String pickupAddress,
    required LatLng location,
    String? providerId,
    int safeHours = 4,
    DateTime? cookedAt,
    DateTime? safeUntil,
    double basePrice = 50.0,
    double floorPrice = 10.0,
    String foodType = 'normal',
    String qualityTier = 'tier1',
    bool clearKitchen = false,
  }) {
    final now = DateTime.now();
    final effectiveCookedAt = cookedAt ?? now;
    final effectiveSafeUntil = safeUntil ?? effectiveCookedAt.add(Duration(hours: safeHours));
    final randomPickupOtp = '${(1000 + (now.millisecond * 9) % 9000).toInt()}';
    final randomDeliveryOtp = '${(2000 + (now.microsecond * 7) % 8000).toInt()}';

    final effectiveProviderId = (providerId != null && providerId.isNotEmpty)
        ? providerId
        : SupabaseService.currentUser?.id;

    final batch = SurplusBatch(
      id: 'BATCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      providerId: effectiveProviderId,
      providerName: providerName,
      providerCategory: providerCategory,
      location: location,
      title: title,
      category: category,
      quantityPortions: quantityPortions,
      dietaryType: dietaryType,
      cookedAt: effectiveCookedAt,
      safeUntil: effectiveSafeUntil,
      temperatureCelsius: temperatureCelsius,
      packagingType: packagingType,
      pickupAddress: pickupAddress,
      pickupOtp: randomPickupOtp,
      deliveryOtp: randomDeliveryOtp,
      basePrice: basePrice,
      floorPrice: floorPrice,
      foodType: foodType,
      qualityTier: qualityTier,
      clearKitchen: clearKitchen,
      status: BatchStatus.available,
    );

    // Instant local update (0ms latency for UI)
    _batches.insert(0, batch);
    notifyListeners();

    // Async sync to Supabase table
    _syncBatchUpsert(batch);

    return batch;
  }

  /// Delete a batch
  Future<bool> deleteBatch(String batchId) async {
    _batches.removeWhere((b) => b.id == batchId);
    notifyListeners();

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('surplus_batches')
            .delete()
            .eq('id', batchId);
        debugPrint('Deleted batch: $batchId');
        return true;
      } catch (err) {
        debugPrint('Supabase delete notice: $err');
        return true;
      }
    }
    return true;
  }

  /// Simulate or process NGO claim for real-time demonstration
  void simulateClaim(String batchId, {String ngoName = 'Hope Children Shelter', String courierName = 'Vikram Rao'}) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return;

    final batch = _batches[index];
    final pricing = batch.dynamicPricing;
    batch.lockedUnitPrice = pricing.currentPrice;
    batch.lockedTotalPrice = pricing.totalPrice;
    batch.discountAtPurchase = pricing.discountPercentage;
    batch.timeRemainingHoursAtPurchase = pricing.timeRemainingHours;

    batch.status = BatchStatus.claimed;
    batch.claimedByNgo = ngoName;
    batch.claimedByNgoId = SupabaseService.currentUser?.id;
    batch.assignedCourierName = courierName;
    batch.assignedCourierPhone = '+91 98765 43210';
    batch.courierEtaMinutes = 8;
    batch.claimedAt = DateTime.now();

    notifyListeners();
    _syncBatchUpsert(batch);
  }

  /// Unclaim a batch
  void unclaimBatch(String batchId) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return;

    final batch = _batches[index];
    batch.status = BatchStatus.available;
    batch.claimedByNgo = null;
    batch.claimedByNgoId = null;
    batch.assignedCourierName = null;
    batch.assignedCourierPhone = null;
    batch.courierEtaMinutes = null;
    batch.claimedAt = null;
    batch.lockedUnitPrice = null;
    batch.lockedTotalPrice = null;
    batch.discountAtPurchase = null;
    batch.timeRemainingHoursAtPurchase = null;

    notifyListeners();
    _syncBatchUpsert(batch);
  }

  /// NGO Claims a batch
  bool claimBatch({
    required String batchId,
    required String ngoName,
    String? claimedByNgoId,
    bool requestVolunteerCourier = true,
  }) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;

    final batch = _batches[index];
    if (batch.status != BatchStatus.available) return false;

    // Safety check: Do not allow claim if food is expired
    if (batch.isExpired) {
      batch.status = BatchStatus.expired;
      notifyListeners();
      return false;
    }

    // Lock price at the moment of purchase/claim
    final pricing = batch.dynamicPricing;
    batch.lockedUnitPrice = pricing.currentPrice;
    batch.lockedTotalPrice = pricing.totalPrice;
    batch.discountAtPurchase = pricing.discountPercentage;
    batch.timeRemainingHoursAtPurchase = pricing.timeRemainingHours;

    batch.status = BatchStatus.claimed;
    batch.claimedByNgo = ngoName;
    batch.claimedByNgoId = claimedByNgoId ?? SupabaseService.currentUser?.id;
    batch.claimedAt = DateTime.now();

    if (requestVolunteerCourier) {
      batch.assignedCourierName = 'Rahul Sharma (Volunteer Squad)';
      batch.assignedCourierPhone = '+91 95556 51225';
      batch.courierEtaMinutes = 12;
    } else {
      batch.assignedCourierName = '$ngoName Internal Volunteer Team';
      batch.assignedCourierPhone = '+91 98765 01234';
      batch.courierEtaMinutes = 20;
    }

    notifyListeners();

    // Instant targeted update to Supabase for immediate cross-tab synchronization
    _syncBatchUpdate(batch, {
      'status': BatchStatus.claimed.name,
      'claimed_by_ngo_name': ngoName,
      if (batch.claimedByNgoId != null && SurplusBatch._isValidUuid(batch.claimedByNgoId!))
        'claimed_by_ngo_id': batch.claimedByNgoId,
      'claimed_at': batch.claimedAt?.toUtc().toIso8601String(),
      'assigned_courier_name': batch.assignedCourierName,
      'assigned_courier_phone': batch.assignedCourierPhone,
      'courier_eta_minutes': batch.courierEtaMinutes,
    });

    return true;
  }

  /// Courier verifies pickup OTP at kitchen
  bool verifyPickupOtp(String batchId, String otpEntered) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;

    final batch = _batches[index];
    if (batch.pickupOtp == otpEntered.trim()) {
      batch.status = BatchStatus.pickedUp;
      batch.pickedUpAt = DateTime.now();
      notifyListeners();
      _syncBatchUpdate(batch);
      return true;
    }
    return false;
  }

  /// Shelter verifies delivery OTP upon arrival
  bool verifyDeliveryOtp(String batchId, String otpEntered) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;

    final batch = _batches[index];
    if (batch.deliveryOtp == otpEntered.trim()) {
      batch.status = BatchStatus.delivered;
      batch.deliveredAt = DateTime.now();
      notifyListeners();
      _syncBatchUpdate(batch);
      return true;
    }
    return false;
  }

  // Simulation tracking maps
  final Map<String, Timer> _simulationTimers = {};
  final Map<String, double> _simulationProgress = {};
  final Map<String, double> _simulationSpeeds = {};
  final Map<String, bool> _simulationPaused = {};

  bool isSimulationRunning(String batchId) =>
      _simulationTimers.containsKey(batchId) && !(_simulationPaused[batchId] ?? false);

  bool isSimulationPaused(String batchId) => _simulationPaused[batchId] ?? false;

  double getSimulationSpeed(String batchId) => _simulationSpeeds[batchId] ?? 1.0;

  /// Active delivery task for the current volunteer (if any)
  SurplusBatch? getActiveTaskForVolunteer([String? volunteerId]) {
    final currentId = volunteerId ?? SupabaseService.currentUser?.id;
    return _batches.cast<SurplusBatch?>().firstWhere(
      (b) {
        if (b == null) return false;
        final isMyCourier = currentId != null && b.assignedCourierId == currentId;
        final isPendingTransit = b.status == BatchStatus.volunteerAssigning ||
            b.status == BatchStatus.inTransitToPickup ||
            b.status == BatchStatus.arrivedAtPickup ||
            b.status == BatchStatus.pickedUp ||
            b.status == BatchStatus.inTransit ||
            b.status == BatchStatus.arrivedAtReceiver;
        return isPendingTransit && (isMyCourier || currentId == null);
      },
      orElse: () => null,
    );
  }

  /// Start volunteer assignment handshake (volunteerAssigning stage)
  bool startVolunteerAssignment({
    required String batchId,
    required String volunteerId,
    required String volunteerName,
    String? volunteerPhone,
    bool autoFinalize = true,
    Duration finalizeDelay = const Duration(milliseconds: 2500),
  }) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;

    final batch = _batches[index];
    // Atomic safety: cannot accept if already assigned to someone else
    if (batch.assignedCourierId != null &&
        batch.assignedCourierId!.isNotEmpty &&
        batch.assignedCourierId != volunteerId) {
      return false;
    }

    batch.assignedCourierId = volunteerId;
    batch.assignedCourierName = volunteerName;
    batch.assignedCourierPhone = volunteerPhone ?? '+91 95556 51225';
    batch.courierEtaMinutes = 12;
    batch.distanceRemainingKm = 2.4;
    batch.status = BatchStatus.volunteerAssigning;
    batch.assigningStartedAt = DateTime.now();

    // Initial position: slightly offset from provider kitchen (~1.2 km away)
    batch.courierCurrentLat = batch.location.latitude - 0.009;
    batch.courierCurrentLng = batch.location.longitude - 0.007;

    notifyListeners();

    _syncBatchUpdate(batch, {
      if (volunteerId.isNotEmpty && SurplusBatch._isValidUuid(volunteerId))
        'assigned_courier_id': volunteerId,
      'assigned_courier_name': volunteerName,
      'assigned_courier_phone': batch.assignedCourierPhone,
      'status': BatchStatus.volunteerAssigning.name,
      'courier_eta_minutes': batch.courierEtaMinutes,
    });

    // Check if test environment to avoid blocking test runners
    bool isTest = false;
    try {
      isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      isTest = true;
    }

    if (autoFinalize) {
      if (isTest) {
        finalizeVolunteerAssignment(batchId);
      } else {
        Timer(finalizeDelay, () {
          finalizeVolunteerAssignment(batchId);
        });
      }
    }

    return true;
  }

  /// Finalize assignment from volunteerAssigning -> inTransitToPickup
  void finalizeVolunteerAssignment(String batchId) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return;

    final batch = _batches[index];
    if (batch.status == BatchStatus.volunteerAssigning) {
      batch.status = BatchStatus.inTransitToPickup;
      notifyListeners();

      _syncBatchUpdate(batch, {
        'status': BatchStatus.inTransitToPickup.name,
      });

      // Start simulated movement engine in non-test mode
      bool isTest = false;
      try {
        isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      } catch (_) {
        isTest = true;
      }
      if (!isTest) {
        startSimulatedMovement(batchId);
      }
    }
  }

  /// Accept a delivery task (routes through startVolunteerAssignment)
  bool acceptDeliveryTask({
    required String batchId,
    required String volunteerId,
    required String volunteerName,
    String? volunteerPhone,
    bool delayFinalize = true,
  }) {
    return startVolunteerAssignment(
      batchId: batchId,
      volunteerId: volunteerId,
      volunteerName: volunteerName,
      volunteerPhone: volunteerPhone,
      autoFinalize: delayFinalize,
    );
  }

  /// Start simulated movement along the route
  void startSimulatedMovement(String batchId, {double speedMultiplier = 1.0}) {
    stopSimulatedMovement(batchId);

    _simulationSpeeds[batchId] = speedMultiplier;
    _simulationPaused[batchId] = false;
    _simulationProgress[batchId] = _simulationProgress[batchId] ?? 0.0;

    _simulationTimers[batchId] = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      final index = _batches.indexWhere((b) => b.id == batchId);
      if (index == -1) {
        timer.cancel();
        return;
      }

      final batch = _batches[index];
      if (_simulationPaused[batchId] == true) return;

      final speed = _simulationSpeeds[batchId] ?? 1.0;

      // Leg 1: Volunteer -> Provider Kitchen
      if (batch.status == BatchStatus.inTransitToPickup) {
        double p = (_simulationProgress[batchId] ?? 0.0) + (0.08 * speed);
        if (p >= 1.0) {
          p = 1.0;
          batch.courierCurrentLat = batch.location.latitude;
          batch.courierCurrentLng = batch.location.longitude;
          batch.distanceRemainingKm = 0.0;
          batch.courierEtaMinutes = 0;
          batch.status = BatchStatus.arrivedAtPickup;
          _simulationProgress[batchId] = 0.0; // Reset for Leg 2
          notifyListeners();
          _syncBatchUpdate(batch, {
            'status': BatchStatus.arrivedAtPickup.name,
            'courier_latitude': batch.courierCurrentLat,
            'courier_longitude': batch.courierCurrentLng,
            'courier_eta_minutes': 0,
          });
          return;
        }

        _simulationProgress[batchId] = p;
        final startLat = batch.location.latitude - 0.009;
        final startLng = batch.location.longitude - 0.007;
        final targetLat = batch.location.latitude;
        final targetLng = batch.location.longitude;

        batch.courierCurrentLat = startLat + (targetLat - startLat) * p;
        batch.courierCurrentLng = startLng + (targetLng - startLng) * p;
        batch.distanceRemainingKm = double.parse((2.4 * (1.0 - p)).toStringAsFixed(2));
        batch.courierEtaMinutes = math.max(1, (12 * (1.0 - p)).round());
        notifyListeners();
        return;
      }

      // Leg 2: Provider Kitchen -> Receiver Destination
      if (batch.status == BatchStatus.pickedUp || batch.status == BatchStatus.inTransit) {
        if (batch.status == BatchStatus.pickedUp) {
          batch.status = BatchStatus.inTransit;
        }

        double p = (_simulationProgress[batchId] ?? 0.0) + (0.06 * speed);
        final receiverPos = batch.receiverCoordinates;

        if (p >= 1.0) {
          p = 1.0;
          batch.courierCurrentLat = receiverPos.latitude;
          batch.courierCurrentLng = receiverPos.longitude;
          batch.distanceRemainingKm = 0.0;
          batch.courierEtaMinutes = 0;
          batch.status = BatchStatus.arrivedAtReceiver;
          _simulationProgress[batchId] = 1.0;
          timer.cancel();
          _simulationTimers.remove(batchId);
          notifyListeners();
          _syncBatchUpdate(batch, {
            'status': BatchStatus.arrivedAtReceiver.name,
            'courier_latitude': batch.courierCurrentLat,
            'courier_longitude': batch.courierCurrentLng,
            'courier_eta_minutes': 0,
          });
          return;
        }

        _simulationProgress[batchId] = p;
        final startLat = batch.location.latitude;
        final startLng = batch.location.longitude;
        final targetLat = receiverPos.latitude;
        final targetLng = receiverPos.longitude;

        batch.courierCurrentLat = startLat + (targetLat - startLat) * p;
        batch.courierCurrentLng = startLng + (targetLng - startLng) * p;
        batch.distanceRemainingKm = double.parse((3.8 * (1.0 - p)).toStringAsFixed(2));
        batch.courierEtaMinutes = math.max(1, (18 * (1.0 - p)).round());
        notifyListeners();
        return;
      }

      if (batch.status == BatchStatus.delivered ||
          batch.status == BatchStatus.cancelled ||
          batch.status == BatchStatus.expired) {
        timer.cancel();
        _simulationTimers.remove(batchId);
      }
    });
  }

  void pauseSimulatedMovement(String batchId) {
    _simulationPaused[batchId] = true;
    notifyListeners();
  }

  void resumeSimulatedMovement(String batchId) {
    _simulationPaused[batchId] = false;
    notifyListeners();
  }

  void stopSimulatedMovement(String batchId) {
    _simulationTimers[batchId]?.cancel();
    _simulationTimers.remove(batchId);
    _simulationPaused.remove(batchId);
  }

  void setSimulationSpeed(String batchId, double speed) {
    _simulationSpeeds[batchId] = speed;
    notifyListeners();
  }

  /// Update courier GPS location directly (from real device location)
  void updateCourierLocation({
    required String batchId,
    required double latitude,
    required double longitude,
    double? heading,
    double? distanceKm,
    int? etaMinutes,
  }) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return;

    final batch = _batches[index];
    batch.courierCurrentLat = latitude;
    batch.courierCurrentLng = longitude;
    if (heading != null) batch.courierHeading = heading;
    if (distanceKm != null) batch.distanceRemainingKm = distanceKm;
    if (etaMinutes != null) batch.courierEtaMinutes = etaMinutes;
    notifyListeners();
  }

  /// Advance delivery status (e.g. inTransitToPickup -> pickedUp -> delivered)
  void updateTaskDeliveryStatus(String batchId, BatchStatus newStatus) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return;

    final batch = _batches[index];
    batch.status = newStatus;
    if (newStatus == BatchStatus.pickedUp) {
      batch.pickedUpAt = DateTime.now();
      _simulationProgress[batchId] = 0.0;
      startSimulatedMovement(batchId);
    } else if (newStatus == BatchStatus.delivered) {
      batch.deliveredAt = DateTime.now();
      stopSimulatedMovement(batchId);
    }
    notifyListeners();

    _syncBatchUpdate(batch, {
      'status': newStatus.name,
      if (newStatus == BatchStatus.pickedUp) 'picked_up_at': DateTime.now().toUtc().toIso8601String(),
      if (newStatus == BatchStatus.delivered) 'delivered_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Cancel delivery task assignment
  void cancelDeliveryTask(String batchId, String reason) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return;

    final batch = _batches[index];
    if (batch.status == BatchStatus.delivered) return; // Cannot cancel completed delivery

    stopSimulatedMovement(batchId);
    batch.assignedCourierId = null;
    batch.assignedCourierName = null;
    batch.assignedCourierPhone = null;
    batch.courierEtaMinutes = null;
    batch.distanceRemainingKm = null;
    batch.status = BatchStatus.claimed;
    notifyListeners();

    _syncBatchUpdate(batch, {
      'assigned_courier_id': null,
      'assigned_courier_name': null,
      'assigned_courier_phone': null,
      'status': BatchStatus.claimed.name,
    });
  }

  @override
  void dispose() {
    for (final timer in _simulationTimers.values) {
      timer.cancel();
    }
    _simulationTimers.clear();
    _livePricingTimer?.cancel();
    _syncPollTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
