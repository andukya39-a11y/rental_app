import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:zanzrental/constants/app_colors.dart';

const _kMapsKey = 'AIzaSyA5D5H-3lTkMIuJM4kTLO_anIExo11GLyA';

// Biased to Zanzibar centre
const _kZanLat = -6.1659;
const _kZanLng = 39.2026;

class LocationSearchResult {
  final String name;
  final String fullAddress;
  final double? lat;
  final double? lng;

  const LocationSearchResult({
    required this.name,
    required this.fullAddress,
    this.lat,
    this.lng,
  });
}

/// Tappable field that opens a Google Places Autocomplete search sheet.
///
/// [onSelected] fires with the chosen place whenever the user picks one.
class LocationSearchField extends StatelessWidget {
  final String? value;
  final String hint;
  final String? errorText;
  final bool required;
  final void Function(LocationSearchResult result) onSelected;

  const LocationSearchField({
    super.key,
    this.value,
    this.hint = 'Search shehia area…',
    this.errorText,
    this.required = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null
                    ? Colors.red[400]!
                    : hasValue
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                width: hasValue ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: hasValue ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    style: TextStyle(
                      fontSize: 15,
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  hasValue
                      ? Icons.edit_location_alt_rounded
                      : Icons.search_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<LocationSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LocationSearchSheet(),
    );
    if (result != null) onSelected(result);
  }
}

// ── Bottom Sheet ─────────────────────────────────────────────────────────────

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<_PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isLocating = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final text = _searchCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String input) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final uri = Uri.https(
          'maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': input,
        'key': _kMapsKey,
        'components': 'country:tz',
        'location': '$_kZanLat,$_kZanLng',
        'radius': '60000',
        'language': 'en',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'OK') {
        final preds = body['predictions'] as List<dynamic>;
        setState(() {
          _suggestions = preds
              .map((p) => _PlaceSuggestion.fromJson(p as Map<String, dynamic>))
              .toList();
        });
      } else if (body['status'] == 'ZERO_RESULTS') {
        setState(() => _suggestions = []);
      } else {
        setState(
            () => _searchError = 'Search unavailable. Check your connection.');
      }
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Search failed. Try again.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _searchError = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _searchError = 'Location services are disabled.';
          _isLocating = false;
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _searchError = 'Location permission denied.';
            _isLocating = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      // Reverse geocode
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '${pos.latitude},${pos.longitude}',
        'key': _kMapsKey,
        'language': 'en',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'OK') {
        final results = body['results'] as List<dynamic>;
        if (results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          final rawAddress = r['formatted_address'] as String? ?? '';
          // Extract the most specific locality name from address components
          final components = r['address_components'] as List<dynamic>? ?? [];
          String localityName = '';
          for (final c in components) {
            final types = (c['types'] as List<dynamic>).cast<String>();
            if (types.contains('sublocality_level_1') ||
                types.contains('sublocality') ||
                types.contains('neighborhood') ||
                types.contains('locality')) {
              localityName = c['long_name'] as String? ?? '';
              if (localityName.isNotEmpty) break;
            }
          }
          // Derive a readable short name — prefer locality, then first part of address
          final name = localityName.isNotEmpty
              ? localityName
              : rawAddress.isNotEmpty
                  ? rawAddress.split(',').first.trim()
                  : 'Unknown area';
          // Full address: prefer the formatted address, fall back to coordinates
          final fullAddress = rawAddress.isNotEmpty
              ? rawAddress
              : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
          if (!mounted) return;
          Navigator.of(context).pop(LocationSearchResult(
            name: name,
            fullAddress: fullAddress,
            lat: pos.latitude,
            lng: pos.longitude,
          ));
          return;
        }
      }
      // Reverse geocode returned no usable results — still return with coords
      if (mounted) {
        Navigator.of(context).pop(LocationSearchResult(
          name: 'My location',
          fullAddress:
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
          lat: pos.latitude,
          lng: pos.longitude,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _searchError = 'Location error. Please search manually.');
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    // Fetch place details for lat/lng
    try {
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': suggestion.placeId,
        'fields': 'geometry,name,formatted_address',
        'key': _kMapsKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      final body = json.decode(res.body) as Map<String, dynamic>;
      double? lat, lng;
      String fullAddress = suggestion.description;
      if (body['status'] == 'OK') {
        final result = body['result'] as Map<String, dynamic>;
        final loc = (result['geometry'] as Map<String, dynamic>)['location']
            as Map<String, dynamic>;
        lat = (loc['lat'] as num).toDouble();
        lng = (loc['lng'] as num).toDouble();
        fullAddress = result['formatted_address'] as String? ?? fullAddress;
      }
      if (!mounted) return;
      Navigator.of(context).pop(LocationSearchResult(
        name: suggestion.mainText,
        fullAddress: fullAddress,
        lat: lat,
        lng: lng,
      ));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(LocationSearchResult(
        name: suggestion.mainText,
        fullAddress: suggestion.description,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Title row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Search your shehia area',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // ── Search field ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'e.g. Mji Mkongwe, Ng\'ambo, Fuoni…',
                hintStyle: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                prefixIcon: _isSearching
                    ? Transform.scale(
                        scale: 0.5,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primary),
                      )
                    : const Icon(Icons.search_rounded,
                        size: 20, color: AppColors.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5)),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              ),
            ),
          ),
          // ── Use current location ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: InkWell(
              onTap: _isLocating ? null : _useCurrentLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.my_location_rounded,
                            size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Use my current location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_searchError!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange)),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // ── Results list ────────────────────────────────────────
          Expanded(
            child: _suggestions.isEmpty && _searchCtrl.text.trim().isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Type to search for your area',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : _suggestions.isEmpty && !_isSearching
                    ? Center(
                        child: Text(
                          'No places found for "${_searchCtrl.text}"',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                            top: 8,
                            bottom: bottomPadding + 24,
                            left: 8,
                            right: 8),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 52),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded,
                                  size: 18, color: AppColors.primary),
                            ),
                            title: Text(
                              s.mainText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: s.secondaryText.isNotEmpty
                                ? Text(
                                    s.secondaryText,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _selectSuggestion(s),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const _PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory _PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structured =
        json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return _PlaceSuggestion(
      placeId: json['place_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mainText: structured['main_text'] as String? ??
          json['description'] as String? ??
          '',
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }
}
