import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/services/booking_service.dart';
import 'package:zanzrental/services/house_service.dart';
import 'package:zanzrental/services/recently_viewed_service.dart';
import 'package:zanzrental/widgets/verification_badge.dart';
import 'package:zanzrental/screens/bookings/booking_request_dialog.dart';
import 'package:zanzrental/constants/app_colors.dart';

const _kApiKey = 'AIzaSyA5D5H-3lTkMIuJM4kTLO_anIExo11GLyA';

// ─────────────────────────────────────────────────────────────────
class HouseDetailScreen extends StatefulWidget {
  final HouseModel house;
  const HouseDetailScreen({Key? key, required this.house}) : super(key: key);

  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  // ── Map state ─────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _propertyLatLng;
  LatLng? _userLatLng;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  MapType _mapType = MapType.normal;

  // ── Route state ───────────────────────────────────────────────
  String _distance = '';
  String _duration = '';
  String _travelMode = 'driving'; // driving | walking | transit
  bool _isLoadingMap = true;
  bool _isLoadingRoute = false;

  // ── UI state ──────────────────────────────────────────────────
  bool _isRequestingVerification = false;
  bool _descriptionExpanded = false;
  bool _isFavorite = false;
  bool _isBooked = false;

  // ── Contact / ownership state ─────────────────────────────────
  String? _currentUid;
  String? _ownerPhone;
  String? _tenantPhone;
  String? _tenantName;

  bool get _isOwner =>
      _currentUid != null && _currentUid == widget.house.userId;

  @override
  void initState() {
    super.initState();
    RecentlyViewedService().addRecentlyViewedHouse(widget.house.id);
    _initMap();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!mounted) return;
    setState(() => _currentUid = uid);

    // Fetch owner phone
    final owner = await AuthService().getUserById(widget.house.userId);
    if (mounted) setState(() => _ownerPhone = owner?.phoneNumber);

    // Fetch confirmed booking — needed for isBooked flag and tenant contact
    final booking =
        await BookingService().getConfirmedBookingForProperty(widget.house.id);
    if (!mounted) return;
    setState(() => _isBooked = booking != null);

    // If current viewer is the owner, also load the tenant's phone
    if (uid == widget.house.userId && booking != null) {
      final tenant = await AuthService().getUserById(booking.tenantId);
      if (mounted) {
        setState(() {
          _tenantPhone = tenant?.phoneNumber;
          _tenantName =
              booking.tenantName.isNotEmpty ? booking.tenantName : tenant?.name;
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── 1. Initialise map: geocode → user pos → route ─────────────
  Future<void> _initMap() async {
    LatLng? propPos;

    if (widget.house.latitude != null && widget.house.longitude != null) {
      propPos = LatLng(widget.house.latitude!, widget.house.longitude!);
    } else {
      propPos = await _geocode('${widget.house.location}, Zanzibar, Tanzania');
    }

    if (!mounted) return;

    if (propPos != null) {
      setState(() {
        _propertyLatLng = propPos;
        _markers.add(_buildPropertyMarker(propPos!));
      });
    }

    await _requestLocationPermission();

    if (_userLatLng != null && propPos != null) {
      await _fetchRoute();
    }

    if (mounted) setState(() => _isLoadingMap = false);
  }

  // ── 2. Geocoding API ──────────────────────────────────────────
  Future<LatLng?> _geocode(String address) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': address,
        'key': _kApiKey,
        'region': 'tz',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final loc =
            data['results'][0]['geometry']['location'] as Map<String, dynamic>;
        return LatLng(
            (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
      }
    } catch (_) {}
    return null;
  }

  // ── 3. Location permission + user position ────────────────────
  Future<void> _requestLocationPermission() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final userPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLatLng = userPos;
        _markers.add(_buildUserMarker(userPos));
      });
    } catch (_) {}
  }

  // ── 4. Directions API ─────────────────────────────────────────
  Future<void> _fetchRoute() async {
    final prop = _propertyLatLng;
    final user = _userLatLng;
    if (prop == null || user == null) return;

    setState(() {
      _isLoadingRoute = true;
      _polylines.clear();
      _distance = '';
      _duration = '';
    });

    try {
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
        'origin': '${user.latitude},${user.longitude}',
        'destination': '${prop.latitude},${prop.longitude}',
        'mode': _travelMode,
        'key': _kApiKey,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['status'] == 'OK') {
        final route = data['routes'][0] as Map<String, dynamic>;
        final leg = route['legs'][0] as Map<String, dynamic>;
        final encoded = route['overview_polyline']['points'] as String;
        final points = _decodePolyline(encoded);

        if (!mounted) return;
        setState(() {
          _distance = leg['distance']['text'] as String;
          _duration = leg['duration']['text'] as String;
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: AppColors.primary,
            width: 5,
            patterns: const [],
          ));
        });

        // Zoom to fit both points
        _fitBounds(user, prop);
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingRoute = false);
  }

  void _fitBounds(LatLng a, LatLng b) {
    final sw = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 60),
    );
  }

  // ── 5. Open directions in native Maps app ─────────────────────
  Future<void> _openDirections() async {
    final prop = _propertyLatLng;
    final modeMap = {
      'driving': 'd',
      'walking': 'w',
      'transit': 'r',
    };
    final mode = modeMap[_travelMode] ?? 'd';

    if (prop != null) {
      final goog = Uri.parse(
          'comgooglemaps://?daddr=${prop.latitude},${prop.longitude}&directionsmode=$_travelMode');
      final web = Uri.parse('https://www.google.com/maps/dir/?api=1'
          '&destination=${prop.latitude},${prop.longitude}'
          '&travelmode=$_travelMode');

      if (await canLaunchUrl(goog)) {
        await launchUrl(goog);
        return;
      }
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } else {
      final query = Uri.encodeComponent(widget.house.location);
      final url =
          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query'
              '&travelmode=$_travelMode&dirflg=$mode');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openGoogleMaps() async {
    final prop = _propertyLatLng;
    final url = prop != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${prop.latitude},${prop.longitude}')
        : Uri.parse(
            'https://www.google.com/maps/search/${Uri.encodeComponent(widget.house.location)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ── 6. Change travel mode ─────────────────────────────────────
  Future<void> _changeTravelMode(String mode) async {
    if (_travelMode == mode) return;
    setState(() => _travelMode = mode);
    await _fetchRoute();
  }

  // ── Marker builders ───────────────────────────────────────────
  Marker _buildPropertyMarker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('property'),
      position: pos,
      infoWindow: InfoWindow(
        title: widget.house.title,
        snippet: widget.house.location,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
  }

  Marker _buildUserMarker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('user'),
      position: pos,
      infoWindow: const InfoWindow(title: 'Your Location'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  // ── Polyline decoder (Google's encoded format) ────────────────
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ── Other actions ─────────────────────────────────────────────
  Future<void> _showBookingDialog() async {
    await showDialog(
      context: context,
      builder: (_) => BookingRequestDialog(
        houseId: widget.house.id,
        houseTitle: widget.house.title,
        houseImageUrl: widget.house.imageUrl ?? '',
        houseLocation: widget.house.location,
        landlordId: widget.house.userId,
        verificationStatus: widget.house.verificationStatus,
        minRentalMonths: widget.house.minRentalMonths,
        pricePerMonth: widget.house.price,
      ),
    );
  }

  Future<void> _requestVerification() async {
    setState(() => _isRequestingVerification = true);
    try {
      await HouseService().requestShehaVerification(widget.house.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sheha verification request submitted!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRequestingVerification = false);
    }
  }

  // Synchronous check is not possible without async; default false for safety.
  // Screens that need this should load storedUser in initState.
  bool get _isLandlord => false;

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return 'TSh ${(price / 1000000).toStringAsFixed(1)}M';
    }
    if (price >= 1000) return 'TSh ${(price / 1000).toStringAsFixed(0)}K';
    return 'TSh ${price.toStringAsFixed(0)}';
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _buildFloatingAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildStickyBar(),
    );
  }

  // ── Floating AppBar over hero photo ──────────────────────────
  Widget _buildFloatingAppBar() {
    final imageUrl = widget.house.imageUrl;
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _CircleBtn(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _CircleBtn(
            icon: Icons.share_outlined,
            onTap: _openGoogleMaps,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _CircleBtn(
            icon: _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: _isFavorite ? Colors.red : AppColors.textPrimary,
            onTap: () => setState(() => _isFavorite = !_isFavorite),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.none,
        background: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(color: const Color(0xFFF0F0F0));
                },
                errorBuilder: (_, __, ___) => _photoPlaceholder(),
              )
            : _photoPlaceholder(),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No photo',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Main scrollable body ──────────────────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          const SizedBox(height: 8),
          _buildSubtitleRow(),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),
          _buildHostCard(),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 20),
          _buildAmenitiesGrid(),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 20),
          _buildDescription(),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 20),
          _buildLocationSection(),
          if (_isLandlord) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),
            _buildVerificationButton(),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.house.title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
    );
  }

  Widget _buildSubtitleRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                widget.house.location,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        VerificationBadge(verificationStatus: widget.house.verificationStatus),
        _StatusChip(
          label: widget.house.isAvailable ? 'Available' : 'Rented',
          color: widget.house.isAvailable ? Colors.green : Colors.red,
        ),
        if (widget.house.propertyType != null &&
            widget.house.propertyType!.isNotEmpty)
          _StatusChip(
            label: widget.house.propertyType!,
            color: AppColors.primary,
          ),
      ],
    );
  }

  Widget _buildHostCard() {
    final name = widget.house.landlordName;
    final email = widget.house.landlordEmail;
    if (name == null && email == null && _ownerPhone == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hosted by',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    name ?? 'Property Owner',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (email != null && email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (_ownerPhone != null && !_isOwner)
              GestureDetector(
                onTap: () => _launchPhone(_ownerPhone!),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 18, color: AppColors.primary),
                ),
              ),
          ],
        ),
        if (_ownerPhone != null && !_isOwner) ...[
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.phone_rounded,
            label: 'Owner phone',
            value: _ownerPhone!,
            onTap: () => _launchPhone(_ownerPhone!),
          ),
        ],
        // Tenant contact — shown only to the property owner when rented
        if (_isOwner && _tenantPhone != null) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_rounded,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current tenant',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      _tenantName ?? 'Tenant',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _launchPhone(_tenantPhone!),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 18, color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.phone_rounded,
            label: 'Tenant phone',
            value: _tenantPhone!,
            color: Colors.green,
            onTap: () => _launchPhone(_tenantPhone!),
          ),
        ],
      ],
    );
  }

  void _launchPhone(String phone) {
    launchUrl(Uri.parse('tel:$phone'));
  }

  Widget _buildAmenitiesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _AmenityTile(
                icon: Icons.bed_rounded,
                label:
                    '${widget.house.bedrooms} ${widget.house.bedrooms == 1 ? "Bedroom" : "Bedrooms"}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AmenityTile(
                icon: Icons.bathtub_rounded,
                label:
                    '${widget.house.bathrooms} ${widget.house.bathrooms == 1 ? "Bathroom" : "Bathrooms"}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AmenityTile(
          icon: Icons.calendar_month_rounded,
          label:
              '${widget.house.minRentalMonths} Month${widget.house.minRentalMonths == 1 ? "" : "s"} min. per settlement',
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final desc = widget.house.description;
    const maxChars = 200;
    final isLong = desc.length > maxChars;
    final displayText = _descriptionExpanded || !isLong
        ? desc
        : '${desc.substring(0, maxChars)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About this place',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          displayText,
          style: const TextStyle(
            fontSize: 15,
            height: 1.65,
            color: AppColors.textSecondary,
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () =>
                setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Text(
              _descriptionExpanded ? 'Show less' : 'Show more',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Location section with full map + directions ───────────────
  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Where you\'ll be',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (!_isLoadingMap && _propertyLatLng != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FullMapScreen(
                    title: widget.house.title,
                    propertyLatLng: _propertyLatLng!,
                    userLatLng: _userLatLng,
                    markers: _markers,
                    polylines: _polylines,
                  ),
                )),
                child: const Row(
                  children: [
                    Text(
                      'Full map',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.open_in_new_rounded,
                        size: 13, color: AppColors.primary),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.house.location,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        // ── Embedded map ──────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: _isLoadingMap
                ? Container(
                    color: const Color(0xFFF0F0F0),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('Loading map…',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : _propertyLatLng == null
                    ? _mapUnavailable()
                    : Stack(
                        children: [
                          GoogleMap(
                            mapType: _mapType,
                            initialCameraPosition: CameraPosition(
                              target: _propertyLatLng!,
                              zoom: 15,
                            ),
                            onMapCreated: (c) {
                              _mapController = c;
                              if (_userLatLng != null) {
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () => _fitBounds(
                                      _userLatLng!, _propertyLatLng!),
                                );
                              }
                            },
                            markers: _markers,
                            polylines: _polylines,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            compassEnabled: false,
                          ),
                          // Map type toggle
                          Positioned(
                            top: 10,
                            left: 10,
                            child: _MapOverlayBtn(
                              icon: _mapType == MapType.normal
                                  ? Icons.satellite_alt_rounded
                                  : Icons.map_rounded,
                              tooltip: _mapType == MapType.normal
                                  ? 'Satellite'
                                  : 'Map',
                              onTap: () => setState(() {
                                _mapType = _mapType == MapType.normal
                                    ? MapType.satellite
                                    : MapType.normal;
                              }),
                            ),
                          ),
                          // Fullscreen button
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _MapOverlayBtn(
                              icon: Icons.fullscreen_rounded,
                              tooltip: 'Full screen',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _FullMapScreen(
                                    title: widget.house.title,
                                    propertyLatLng: _propertyLatLng!,
                                    userLatLng: _userLatLng,
                                    markers: _markers,
                                    polylines: _polylines,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // My location button
                          if (_userLatLng != null)
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: _MapOverlayBtn(
                                icon: Icons.my_location_rounded,
                                tooltip: 'My location',
                                onTap: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                        _userLatLng!, 15),
                                  );
                                },
                              ),
                            ),
                          // Route loading overlay
                          if (_isLoadingRoute)
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.12),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Finding route…',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Distance / Duration info bar ──────────────────────
        if (_distance.isNotEmpty && _duration.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary),
                      children: [
                        TextSpan(
                          text: _distance,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: '  ·  ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: _duration,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: ' away',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ── Travel mode selector ──────────────────────────────
        if (_userLatLng != null)
          Row(
            children: [
              _TravelModeBtn(
                icon: Icons.directions_car_rounded,
                label: 'Drive',
                mode: 'driving',
                selected: _travelMode == 'driving',
                onTap: _changeTravelMode,
              ),
              const SizedBox(width: 8),
              _TravelModeBtn(
                icon: Icons.directions_walk_rounded,
                label: 'Walk',
                mode: 'walking',
                selected: _travelMode == 'walking',
                onTap: _changeTravelMode,
              ),
              const SizedBox(width: 8),
              _TravelModeBtn(
                icon: Icons.directions_transit_rounded,
                label: 'Transit',
                mode: 'transit',
                selected: _travelMode == 'transit',
                onTap: _changeTravelMode,
              ),
            ],
          ),

        const SizedBox(height: 12),

        // ── Action buttons ────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text('Directions'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openGoogleMaps,
                icon: const Icon(Icons.map_rounded, size: 16),
                label: const Text('Open Maps'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mapUnavailable() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded,
                size: 40, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text('Location not available',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isRequestingVerification ? null : _requestVerification,
        icon: _isRequestingVerification
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.verified_user_rounded, size: 18),
        label: Text(
          _isRequestingVerification
              ? 'Submitting…'
              : 'Request Sheha Verification',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2E7D32),
          side: const BorderSide(color: Color(0xFF2E7D32)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Sticky bottom bar ─────────────────────────────────────────
  Widget _buildStickyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.textPrimary),
                    children: [
                      TextSpan(
                        text: _formatPrice(widget.house.price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' /month',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Min. ${widget.house.minRentalMonths} month${widget.house.minRentalMonths == 1 ? '' : 's'}/settlement',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 48,
            child: _isOwner
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Your Property',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  )
                : _isBooked || !widget.house.isAvailable
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.do_not_disturb_rounded,
                                size: 16, color: Colors.red),
                            SizedBox(width: 6),
                            Text(
                              'Booked / Rented',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _showBookingDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 0),
                        ),
                        child: const Text(
                          'Reserve',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Full-screen map screen
// ═════════════════════════════════════════════════════════════════
class _FullMapScreen extends StatefulWidget {
  final String title;
  final LatLng propertyLatLng;
  final LatLng? userLatLng;
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  const _FullMapScreen({
    required this.title,
    required this.propertyLatLng,
    this.userLatLng,
    required this.markers,
    required this.polylines,
  });

  @override
  State<_FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<_FullMapScreen> {
  GoogleMapController? _ctrl;
  MapType _mapType = MapType.normal;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: _CircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
            ],
          ),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CircleBtn(
              icon: _mapType == MapType.normal
                  ? Icons.satellite_alt_rounded
                  : Icons.map_rounded,
              onTap: () => setState(() {
                _mapType = _mapType == MapType.normal
                    ? MapType.satellite
                    : MapType.normal;
              }),
            ),
          ),
        ],
      ),
      body: GoogleMap(
        mapType: _mapType,
        initialCameraPosition: CameraPosition(
          target: widget.propertyLatLng,
          zoom: 15,
        ),
        onMapCreated: (c) {
          _ctrl = c;
          if (widget.userLatLng != null) {
            Future.delayed(const Duration(milliseconds: 400), () {
              final sw = LatLng(
                widget.userLatLng!.latitude < widget.propertyLatLng.latitude
                    ? widget.userLatLng!.latitude
                    : widget.propertyLatLng.latitude,
                widget.userLatLng!.longitude < widget.propertyLatLng.longitude
                    ? widget.userLatLng!.longitude
                    : widget.propertyLatLng.longitude,
              );
              final ne = LatLng(
                widget.userLatLng!.latitude > widget.propertyLatLng.latitude
                    ? widget.userLatLng!.latitude
                    : widget.propertyLatLng.latitude,
                widget.userLatLng!.longitude > widget.propertyLatLng.longitude
                    ? widget.userLatLng!.longitude
                    : widget.propertyLatLng.longitude,
              );
              c.animateCamera(CameraUpdate.newLatLngBounds(
                  LatLngBounds(southwest: sw, northeast: ne), 80));
            });
          }
        },
        markers: widget.markers,
        polylines: widget.polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
        trafficEnabled: true,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Small reusable widgets
// ═════════════════════════════════════════════════════════════════

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child:
              Icon(icon, size: 18, color: iconColor ?? AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _MapOverlayBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapOverlayBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)
            ],
          ),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TravelModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String mode;
  final bool selected;
  final Future<void> Function(String) onTap;

  const _TravelModeBtn({
    required this.icon,
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class _AmenityTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AmenityTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
