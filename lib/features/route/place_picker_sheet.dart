import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/geocoding_service.dart';

/// A place picked as a route endpoint. [isMyLocation] marks the "Ma
/// position" shortcut, resolved to GPS coordinates only when routing.
class PickedPlace {
  const PickedPlace({
    required this.label,
    this.lat,
    this.lng,
    this.isMyLocation = false,
  });

  static const myLocation = PickedPlace(
    label: 'Ma position',
    isMyLocation: true,
  );

  final String label;
  final double? lat;
  final double? lng;
  final bool isMyLocation;
}

/// Full-height sheet with an address field and live Nominatim suggestions.
Future<PickedPlace?> showPlacePicker(
  BuildContext context, {
  required String title,
  bool offerMyLocation = false,
}) {
  return showModalBottomSheet<PickedPlace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _PlacePicker(title: title, offerMyLocation: offerMyLocation),
  );
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({required this.title, required this.offerMyLocation});

  final String title;
  final bool offerMyLocation;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final _geocoding = GeocodingService();
  Timer? _debounce;
  int _token = 0;
  List<GeocodingResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final token = ++_token;
    setState(() => _loading = true);
    List<GeocodingResult> results;
    try {
      results = await _geocoding.search(query);
    } catch (_) {
      results = const [];
    }
    if (!mounted || token != _token) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Ville, adresse…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (widget.offerMyLocation)
                    ListTile(
                      leading: const Icon(Icons.my_location_rounded),
                      title: const Text('Ma position'),
                      onTap: () =>
                          Navigator.of(context).pop(PickedPlace.myLocation),
                    ),
                  for (final r in _results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(r.label.split(',').first),
                      subtitle: Text(
                        r.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(
                        PickedPlace(
                          label: r.label.split(',').first,
                          lat: r.lat,
                          lng: r.lng,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
