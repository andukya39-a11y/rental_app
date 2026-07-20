import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/services/preferences_service.dart';
import 'package:zanzrental/models/preferences_model.dart';
import 'package:zanzrental/constants/app_colors.dart';

const _kMapsApiKey = 'AIzaSyA5D5H-3lTkMIuJM4kTLO_anIExo11GLyA';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _preferencesService = PreferencesService();
  String _userId = '';
  bool _isLoading = true;
  bool _isSaving = false;

  Preferences _prefs = Preferences(
    preferredAreas: [],
    minPrice: 0.0,
    maxPrice: 1000000.0,
    propertyType: 'Room',
  );

  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _areaSearchCtrl = TextEditingController();

  // Each suggestion: {mainText, placeId}
  List<Map<String, String>> _areaSuggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;

  static const _types = ['Room', 'Apartment', 'House', 'Studio', 'Villa'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService().getStoredUser();
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _userId = user.id.toString();
    try {
      final prefs = await _preferencesService.getPreferences(_userId);
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _minCtrl.text =
              prefs.minPrice == 0 ? '' : prefs.minPrice.toStringAsFixed(0);
          _maxCtrl.text = prefs.maxPrice == 1000000
              ? ''
              : prefs.maxPrice.toStringAsFixed(0);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final minRaw = _minCtrl.text.trim();
    final maxRaw = _maxCtrl.text.trim();
    final minPrice = minRaw.isEmpty ? 0.0 : double.tryParse(minRaw);
    final maxPrice = maxRaw.isEmpty ? 1000000.0 : double.tryParse(maxRaw);

    if (minPrice == null) {
      _snack('Enter a valid minimum price');
      return;
    }
    if (maxPrice == null) {
      _snack('Enter a valid maximum price');
      return;
    }
    if (minPrice > maxPrice) {
      _snack('Minimum price cannot exceed maximum');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = Preferences(
        preferredAreas: List<Map<String, dynamic>>.from(_prefs.preferredAreas),
        minPrice: minPrice,
        maxPrice: maxPrice,
        propertyType: _prefs.propertyType,
      );
      await _preferencesService.savePreferences(_userId, updated);
      if (!mounted) return;
      setState(() => _prefs = updated);
      _snack('Preferences saved');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to save: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _areaSearchCtrl.dispose();
    super.dispose();
  }

  void _onAreaSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _areaSuggestions = [];
        _loadingSuggestions = false;
      });
      return;
    }
    setState(() => _loadingSuggestions = true);
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchSuggestions(query.trim()),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      // Same parameters as the working LocationSearchField widget:
      // no 'types' filter so sublocalites/neighbourhoods are included,
      // biased to Zanzibar centre coordinates.
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': _kMapsApiKey,
          'components': 'country:tz',
          'location': '-6.1659,39.2026',
          'radius': '60000',
          'language': 'en',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';

      if (status == 'OK') {
        final predictions = data['predictions'] as List<dynamic>;
        setState(() {
          _areaSuggestions = predictions.map((p) {
            final sf = p['structured_formatting'] as Map<String, dynamic>?;
            final mainText = (sf?['main_text'] as String?) ??
                (p['description'] as String? ?? '');
            final placeId = p['place_id'] as String? ?? '';
            return {'mainText': mainText, 'placeId': placeId};
          }).where((s) {
            final name = s['mainText']!;
            return name.isNotEmpty &&
                !_prefs.preferredAreas.any((a) => a['name'] == name);
          }).toList();
        });
      } else {
        setState(() => _areaSuggestions = []);
      }
    } catch (_) {
      if (mounted) setState(() => _areaSuggestions = []);
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _addArea(Map<String, String> suggestion) async {
    final name = suggestion['mainText'] ?? '';
    final placeId = suggestion['placeId'] ?? '';
    if (name.isEmpty) return;
    if (_prefs.preferredAreas.any((a) => a['name'] == name)) return;

    // Add chip immediately with name so UI feels instant
    final entry = <String, dynamic>{'name': name};
    setState(() {
      _prefs.preferredAreas.add(entry);
      _areaSuggestions = [];
      _areaSearchCtrl.clear();
    });

    // Fetch coordinates in the background and patch the entry
    if (placeId.isNotEmpty) {
      try {
        final uri =
            Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': placeId,
          'fields': 'geometry',
          'key': _kMapsApiKey,
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 6));
        if (!mounted) return;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['status'] == 'OK') {
          final loc = ((body['result'] as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>)['location'] as Map<String, dynamic>;
          setState(() {
            entry['lat'] = (loc['lat'] as num).toDouble();
            entry['lng'] = (loc['lng'] as num).toDouble();
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rental Preferences'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _userId.isEmpty
              ? const Center(
                  child: Text('Please log in to set preferences',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                  children: [
                    _buildAreas(),
                    const SizedBox(height: 24),
                    _buildBudget(),
                    const SizedBox(height: 24),
                    _buildPropertyType(),
                  ],
                ),
      bottomNavigationBar: _userId.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Save Preferences',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
    );
  }

  // ── Preferred Areas ──────────────────────────────────────────────

  Widget _buildAreas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PREFERRED AREAS'),
        const SizedBox(height: 4),
        const Text(
          'Search and add areas you would like to rent in',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search field ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _areaSearchCtrl,
                  onChanged: _onAreaSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search location (e.g. Stone Town, Nungwi…)',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textSecondary),
                    suffixIcon: _loadingSuggestions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : _areaSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                onPressed: () {
                                  _areaSearchCtrl.clear();
                                  setState(() => _areaSuggestions = []);
                                },
                              )
                            : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // ── Suggestions list ────────────────────────────
              if (_areaSuggestions.isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.divider),
                ...List.generate(_areaSuggestions.length, (i) {
                  final suggestion = _areaSuggestions[i];
                  final label = suggestion['mainText'] ?? '';
                  return InkWell(
                    onTap: () => _addArea(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textPrimary),
                            ),
                          ),
                          const Icon(Icons.add_rounded,
                              size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(height: 1, color: AppColors.divider),
              ],

              // ── Selected areas as chips ─────────────────────
              if (_prefs.preferredAreas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _prefs.preferredAreas.map((area) {
                      final name = area['name'] as String? ?? '';
                      return Chip(
                        label: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500),
                        ),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                        deleteIcon: const Icon(Icons.close_rounded,
                            size: 14, color: AppColors.primary),
                        onDeleted: () =>
                            setState(() => _prefs.preferredAreas.remove(area)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                )
              else if (_areaSuggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'No areas selected. Search above to add preferred locations.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Budget Range ─────────────────────────────────────────────────

  Widget _buildBudget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('BUDGET RANGE (TSh / MONTH)'),
        const SizedBox(height: 4),
        const Text(
          'Set the price range you can afford',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _budgetField(
                  label: 'Min Price',
                  controller: _minCtrl,
                  hint: '0',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: 24,
                  height: 2,
                  color: AppColors.border,
                ),
              ),
              Expanded(
                child: _budgetField(
                  label: 'Max Price',
                  controller: _maxCtrl,
                  hint: '1,000,000',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _budgetField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: 'TSh ',
            prefixStyle:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Property Type ────────────────────────────────────────────────

  Widget _buildPropertyType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PROPERTY TYPE'),
        const SizedBox(height: 4),
        const Text(
          'What type of property are you looking for?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((type) {
              final selected = _prefs.propertyType == type;
              return GestureDetector(
                onTap: () => setState(() => _prefs.propertyType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      );
}
