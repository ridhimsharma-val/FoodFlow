import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/dynamic_pricing_service.dart';
import '../../services/food_rescue_service.dart';
import '../../services/location_service.dart';
import '../../widgets/osm_map_widget.dart';

class PostFoodPage extends StatefulWidget {
  final String providerName;
  final String providerCategory;
  final String initialLocation;
  final LatLng initialLatLng;
  final VoidCallback onPostedSuccessfully;

  const PostFoodPage({
    super.key,
    required this.providerName,
    required this.providerCategory,
    required this.initialLocation,
    required this.initialLatLng,
    required this.onPostedSuccessfully,
  });

  @override
  State<PostFoodPage> createState() => _PostFoodPageState();
}

class _PostFoodPageState extends State<PostFoodPage> {
  // Step 0: Input Form, Step 1: Review & Confirm
  int _currentStep = 0;

  // Controllers & Form values
  final _foodNameController = TextEditingController(text: 'Rice & Dal');
  final _quantityController = TextEditingController(text: '50');
  final _instructionsController = TextEditingController(text: 'Handle with care. Keep containers upright.');
  final _locationController = TextEditingController();
  final _pickupTimeController = TextEditingController(text: '7:00 PM – 8:00 PM');
  final _basePriceController = TextEditingController(text: '50');
  final _floorPriceController = TextEditingController(text: '10');

  String _selectedCategory = 'Cooked Meal';
  String _selectedDietary = 'Pure Veg';
  final String _selectedFoodType = 'normal';
  final String _selectedQualityTier = 'tier1';
  final bool _clearKitchen = false;
  TimeOfDay _preparedAt = TimeOfDay.now();
  late TimeOfDay _bestBefore;
  late TimeOfDay _pickupStart;
  late TimeOfDay _pickupEnd;
  Duration _shelfLifeDuration = const Duration(hours: 4);
  String _selectedFoodEmoji = '🍲';
  bool _isPosting = false;

  final List<String> _categories = [
    'Cooked Meal',
    'Bakery & Bread',
    'Packaged Goods',
    'Fresh Produce',
    'Raw Grains & Rations',
  ];

  final List<String> _foodVisuals = [
    '🍲', // Dal & Khichdi
    '🍛', // Rice & Biryani
    '🫓', // Roti / Chapati
    '🍱', // Thali / Meal Box
    '🥘', // Sabzi & Curry
    '🥪', // Snacks / Idli / Samosa
    '🍞', // Bakery
    '🌾', // Dry Ration / Grains
  ];

  late LatLng _selectedLatLng;
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _preparedAt = now;
    _pickupStart = now;
    _pickupEnd = TimeOfDay(hour: (now.hour + 2) % 24, minute: now.minute);
    _pickupTimeController.text = '${_formatTimeOfDay(_pickupStart)} – ${_formatTimeOfDay(_pickupEnd)}';
    _updateShelfLifeForCategory(_selectedCategory);
    _selectedLatLng = widget.initialLatLng;
    _locationController.text = widget.initialLocation.isNotEmpty
        ? widget.initialLocation
        : 'ABC Restaurant Kitchen, Greater Noida';
  }

  Duration _getDefaultShelfLifeForCategory(String category) {
    switch (category) {
      case 'Cooked Meal':
        return const Duration(hours: 4);
      case 'Bakery & Bread':
        return const Duration(hours: 24); // 24–48 hours (1 day)
      case 'Packaged Goods':
        return const Duration(days: 7); // 7 days
      case 'Fresh Produce':
        return const Duration(hours: 48); // 48 hours
      case 'Raw Grains & Rations':
        return const Duration(days: 30); // 30 days
      default:
        return const Duration(hours: 4);
    }
  }

  void _updateShelfLifeForCategory(String category) {
    _shelfLifeDuration = _getDefaultShelfLifeForCategory(category);
    final now = DateTime.now();
    final prepDateTime = DateTime(now.year, now.month, now.day, _preparedAt.hour, _preparedAt.minute);
    final target = prepDateTime.add(_shelfLifeDuration);
    _bestBefore = TimeOfDay(hour: target.hour, minute: target.minute);
  }

  String _getShelfLifeBadgeText() {
    if (_shelfLifeDuration.inDays >= 30) {
      return '30 days';
    } else if (_shelfLifeDuration.inDays >= 7) {
      return '7 days';
    } else if (_shelfLifeDuration.inHours >= 48) {
      return '48 hrs';
    } else if (_shelfLifeDuration.inHours >= 24) {
      return '24 hrs';
    } else {
      return '4 hrs';
    }
  }

  Future<void> _detectMyLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final res = await LocationService.detectCurrentLocation();
      if (res != null && mounted) {
        setState(() {
          _selectedLatLng = res.latLng;
          _locationController.text = res.formattedAddress;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('📍 Location updated: ${res.formattedAddress}')),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _onMapTapped(LatLng point) async {
    setState(() {
      _selectedLatLng = point;
    });
    try {
      final res = await LocationService.reverseGeocode(point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _locationController.text = res.formattedAddress;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _quantityController.dispose();
    _instructionsController.dispose();
    _locationController.dispose();
    _pickupTimeController.dispose();
    _basePriceController.dispose();
    _floorPriceController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final min = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _pickTime({required bool isPreparedAt}) async {
    final initial = isPreparedAt ? _preparedAt : _bestBefore;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isPreparedAt ? 'Select Preparation Time' : 'Select Expiration Window Time',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFC107),
              onPrimary: Color(0xFF1E293B),
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isPreparedAt) {
          _preparedAt = picked;
          _updateShelfLifeForCategory(_selectedCategory);
        } else {
          _bestBefore = picked;
        }
      });
    }
  }

  Future<void> _pickPickupWindow() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _pickupStart,
      helpText: 'Select Pickup Window Start Time',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFFC107),
            onPrimary: Color(0xFF1E293B),
            surface: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );

    if (start == null || !mounted) return;

    final initialEnd = TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute);
    final end = await showTimePicker(
      context: context,
      initialTime: initialEnd,
      helpText: 'Select Pickup Window End Time',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFFC107),
            onPrimary: Color(0xFF1E293B),
            surface: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );

    if (end == null || !mounted) return;

    setState(() {
      _pickupStart = start;
      _pickupEnd = end;
      _pickupTimeController.text = '${_formatTimeOfDay(_pickupStart)} – ${_formatTimeOfDay(_pickupEnd)}';
    });
  }

  Future<void> _confirmAndPostFood() async {
    final foodName = _foodNameController.text.trim();
    if (foodName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter food name')),
      );
      setState(() => _currentStep = 0);
      return;
    }

    final qty = int.tryParse(_quantityController.text.trim()) ?? 20;
    final basePrice = double.tryParse(_basePriceController.text.trim()) ?? 50.0;
    final floorPrice = double.tryParse(_floorPriceController.text.trim()) ?? 10.0;

    setState(() => _isPosting = true);

    final now = DateTime.now();
    var cookedAt = DateTime(now.year, now.month, now.day, _preparedAt.hour, _preparedAt.minute);
    if (cookedAt.isAfter(now)) {
      cookedAt = cookedAt.subtract(const Duration(days: 1));
    }
    DateTime safeUntil = DateTime(
      cookedAt.year,
      cookedAt.month,
      cookedAt.day + _shelfLifeDuration.inDays,
      _bestBefore.hour,
      _bestBefore.minute,
    );
    if (safeUntil.isBefore(cookedAt)) {
      safeUntil = safeUntil.add(const Duration(days: 1));
    }
    // Safety guarantee: Ensure newly posted batches have an active safe window
    if (safeUntil.isBefore(now)) {
      safeUntil = now.add(_shelfLifeDuration);
    }

    final batch = FoodRescueService.instance.listNewBatch(
      providerName: widget.providerName,
      providerCategory: widget.providerCategory,
      title: foodName,
      category: _selectedCategory,
      quantityPortions: qty,
      dietaryType: _selectedDietary,
      temperatureCelsius: 65.0,
      packagingType: 'Food-Grade Containers',
      pickupAddress: _locationController.text.trim(),
      location: _selectedLatLng,
      foodEmoji: _selectedFoodEmoji,
      cookedAt: cookedAt,
      safeUntil: safeUntil,
      basePrice: basePrice,
      floorPrice: floorPrice,
      foodType: _selectedFoodType,
      qualityTier: _selectedQualityTier,
      clearKitchen: _clearKitchen,
    );

    setState(() => _isPosting = false);

    // Show Success Dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFFB45309), size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'Surplus Food Live!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${batch.title} ($qty servings) is now broadcast in real-time to verified relief NGOs and shelters.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onPostedSuccessfully();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _currentStep == 0 ? 'Post Surplus Food' : 'Review & Confirm',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _currentStep == 0 ? _buildFormStep() : _buildReviewStep(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Main Form & AI Assistant
  // ---------------------------------------------------------------------------
  Widget _buildFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Minimal Icon Selector ("Food Icon")
        _buildLabel('Food Icon'),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _foodVisuals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final emoji = _foodVisuals[idx];
              final isSelected = _selectedFoodEmoji == emoji;
              return InkWell(
                onTap: () => setState(() => _selectedFoodEmoji = emoji),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // 2. Food Type (Veg / Non-Veg above Food Name)
        _buildLabel('Food Type'),
        Row(
          children: [
            _buildTypeChip('Pure Veg', Icons.eco_rounded, const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _buildTypeChip('Non-Veg', Icons.set_meal_rounded, const Color(0xFFEF4444)),
          ],
        ),

        const SizedBox(height: 18),

        // 3. Food Name
        _buildLabel('Food Name'),
        TextField(
          controller: _foodNameController,
          decoration: _inputDecoration(hint: 'e.g. Rice & Dal, Mixed Sabzi'),
        ),

        const SizedBox(height: 18),

        // 4. Category & Servings Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Category'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _updateShelfLifeForCategory(val);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Quantity / Servings'),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(hint: 'e.g. 50 servings'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 5. Prepared At & Best Consumed Before Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Prepared At'),
                  InkWell(
                    onTap: () => _pickTime(isPreparedAt: true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimeOfDay(_preparedAt),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Best Consumed Before'),
                  InkWell(
                    onTap: () => _pickTime(isPreparedAt: false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_rounded, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatTimeOfDay(_bestBefore),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getShelfLifeBadgeText(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Dynamic Markdown Pricing Section
        _buildPricingSection(),

        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Pickup Location & Kitchen Pin'),
            InkWell(
              onTap: _isDetectingLocation ? null : _detectMyLocation,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isDetectingLocation)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                      )
                    else
                      const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    const Text(
                      'Detect GPS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: _locationController,
          decoration: _inputDecoration(
            hint: 'Use current provider location OR select saved location',
            prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFFFC107), size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.gps_fixed_rounded, color: Color(0xFFD97706), size: 18),
              tooltip: 'Recenter to real GPS location',
              onPressed: _isDetectingLocation ? null : _detectMyLocation,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Interactive Map in Step 0
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Tap anywhere on map to reposition pickup pin / dock',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${_selectedLatLng.latitude.toStringAsFixed(4)}°, ${_selectedLatLng.longitude.toStringAsFixed(4)}°',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              OsmMapWidget(
                key: ValueKey('post_form_map_${_selectedLatLng.latitude}_${_selectedLatLng.longitude}'),
                initialCenter: _selectedLatLng,
                initialZoom: 15.0,
                height: 200,
                showControls: true,
                showRecenterButton: true,
                onRecenter: _detectMyLocation,
                onTap: _onMapTapped,
                markers: [
                  OsmMapMarkerData(
                    point: _selectedLatLng,
                    label: _foodNameController.text.trim().isNotEmpty
                        ? _foodNameController.text.trim()
                        : 'Pickup Dock',
                    subtitle: _locationController.text.trim(),
                    isCenter: true,
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFD97706),
                    badgeText: 'Pickup Pin',
                    badgeColor: const Color(0xFFFFC107),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _buildLabel('Pickup Time Window'),
        InkWell(
          onTap: _pickPickupWindow,
          borderRadius: BorderRadius.circular(10),
          child: IgnorePointer(
            child: TextField(
              controller: _pickupTimeController,
              readOnly: true,
              decoration: _inputDecoration(
                hint: 'e.g. 7:00 PM – 9:00 PM',
                prefixIcon: const Icon(Icons.access_time_rounded, color: Color(0xFF64748B), size: 20),
                suffixIcon: const Icon(Icons.schedule_rounded, color: Color(0xFF94A3B8), size: 20),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        _buildLabel('Special Instructions'),
        TextField(
          controller: _instructionsController,
          maxLines: 2,
          decoration: _inputDecoration(hint: 'e.g. Handle with care, back dock entrance'),
        ),

        const SizedBox(height: 32),

        // Primary Button: Proceed to Review & Confirm
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Review & Confirm →',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Review & Confirm (Section 12)
  // ---------------------------------------------------------------------------
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Food Row
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(_selectedFoodEmoji, style: const TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _foodNameController.text.trim(),
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_quantityController.text.trim()} servings • $_selectedCategory • $_selectedDietary',
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              _buildReviewRow('Prepared At', _formatTimeOfDay(_preparedAt)),
              const SizedBox(height: 10),
              _buildReviewRow('Best Before', '${_formatTimeOfDay(_bestBefore)} (${_getShelfLifeBadgeText()})'),
              const SizedBox(height: 10),
              _buildReviewRow('Base Price', '₹${_basePriceController.text.trim()} / portion'),
              const SizedBox(height: 10),
              _buildReviewRow('Floor Price', '₹${_floorPriceController.text.trim()} / portion (Minimum Limit)'),
              const SizedBox(height: 10),
              _buildReviewRow('Pricing Velocity', '${_selectedFoodType.toUpperCase()} (Tier ${_selectedQualityTier.toUpperCase()})'),
              const SizedBox(height: 10),
              if (_clearKitchen) ...[
                _buildReviewRow('Clear Kitchen', 'Active (50% Flash Clearance Multiplier)'),
                const SizedBox(height: 10),
              ],
              _buildReviewRow('Pickup Location', _locationController.text.trim()),
              const SizedBox(height: 10),
              _buildReviewRow('Pickup Time', _pickupTimeController.text.trim()),
              const SizedBox(height: 10),
              _buildReviewRow('Special Instructions', _instructionsController.text.trim()),
              const SizedBox(height: 10),
              _buildReviewRow('Status', 'Ready to Post (Live Broadcast)'),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Pickup Location Pin Confirmation Map
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pin_drop_rounded, size: 16, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup Location Pin Confirmation',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Dispatch dock verified for volunteers & relief receivers',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedLatLng.latitude.toStringAsFixed(4)}°, ${_selectedLatLng.longitude.toStringAsFixed(4)}°',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              OsmMapWidget(
                key: ValueKey('post_review_map_${_selectedLatLng.latitude}_${_selectedLatLng.longitude}'),
                initialCenter: _selectedLatLng,
                initialZoom: 15.0,
                height: 180,
                showControls: false,
                showRecenterButton: true,
                onRecenter: _detectMyLocation,
                markers: [
                  OsmMapMarkerData(
                    point: _selectedLatLng,
                    label: _foodNameController.text.trim().isNotEmpty
                        ? _foodNameController.text.trim()
                        : 'Pickup Dock',
                    subtitle: _locationController.text.trim(),
                    isCenter: true,
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFD97706),
                    badgeText: 'Verified Pickup Dock',
                    badgeColor: const Color(0xFFFFC107),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Primary & Secondary Buttons
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isPosting ? null : _confirmAndPostFood,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1E293B)),
                  )
                : const Text('Post Food', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => setState(() => _currentStep = 0),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Edit Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DYNAMIC PRICING SECTION (Smart Markdown Engine)
  // ---------------------------------------------------------------------------
  Widget _buildPricingSection() {
    final basePrice = double.tryParse(_basePriceController.text.trim()) ?? 50.0;
    final floorPrice = double.tryParse(_floorPriceController.text.trim()) ?? 10.0;
    final qty = int.tryParse(_quantityController.text.trim()) ?? 20;

    // Simulate preview at fresh listing (now)
    final now = DateTime.now();
    final cookedAt = DateTime(now.year, now.month, now.day, _preparedAt.hour, _preparedAt.minute);
    DateTime safeUntil = DateTime(
      now.year,
      now.month,
      now.day + _shelfLifeDuration.inDays,
      _bestBefore.hour,
      _bestBefore.minute,
    );
    if (safeUntil.isBefore(cookedAt)) {
      safeUntil = safeUntil.add(const Duration(days: 1));
    }

    final freshPreview = DynamicPricingService.calculateDynamicPrice(
      basePrice: basePrice,
      floorPrice: floorPrice,
      foodType: _selectedFoodType,
      qualityTier: _selectedQualityTier,
      quantityPortions: qty,
      clearKitchen: _clearKitchen,
      cookedAt: cookedAt,
      safeUntil: safeUntil,
      currentTime: now,
    );

    // Half life preview
    final totalDuration = safeUntil.difference(cookedAt);
    final halfLifeTime = cookedAt.add(totalDuration * 0.5);
    final halfLifePreview = DynamicPricingService.calculateDynamicPrice(
      basePrice: basePrice,
      floorPrice: floorPrice,
      foodType: _selectedFoodType,
      qualityTier: _selectedQualityTier,
      quantityPortions: qty,
      clearKitchen: _clearKitchen,
      cookedAt: cookedAt,
      safeUntil: safeUntil,
      currentTime: halfLifeTime,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.6), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Dynamic Markdown Pricing',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Price decreases smoothly as safe expiry window approaches',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: const Text(
                  'Automated',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Base Price & Floor Price Inputs
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Base Price / Portion (₹)'),
                    TextField(
                      controller: _basePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hint: 'e.g. 50'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Minimum Price (₹)'),
                    TextField(
                      controller: _floorPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hint: 'e.g. 10'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Live Real-Time Price Simulation Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.insights_rounded, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text(
                          'Live Markdown Preview',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    Text(
                      'Base: ₹${basePrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPreviewColumn(
                        'Launch Price',
                        '₹${freshPreview.currentPrice.toStringAsFixed(1)}',
                        freshPreview.discountBadge,
                        const Color(0xFF10B981),
                      ),
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: _buildPreviewColumn(
                        'Halfway (50% Time)',
                        '₹${halfLifePreview.currentPrice.toStringAsFixed(1)}',
                        halfLifePreview.discountBadge,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: _buildPreviewColumn(
                        'Floor Limit',
                        '₹${floorPrice.toStringAsFixed(1)}',
                        'Guaranteed',
                        const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewColumn(String title, String price, String badge, Color badgeColor) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: badgeColor),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, IconData defaultIcon, Color color) {
    final isSelected = _selectedDietary == label;
    return InkWell(
      onTap: () => setState(() => _selectedDietary = label),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : defaultIcon,
              color: isSelected ? color : const Color(0xFF94A3B8),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
      ),
    );
  }
}
