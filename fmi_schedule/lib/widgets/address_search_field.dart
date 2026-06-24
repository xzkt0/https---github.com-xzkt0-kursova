import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';

class AddressSearchField extends StatefulWidget {
  final String? initialValue;
  final String hintText;
  final IconData prefixIcon;
  final void Function(String address, double lat, double lng) onSelected;
  final VoidCallback? onCleared;

  const AddressSearchField({
    super.key,
    this.initialValue,
    required this.hintText,
    this.prefixIcon = Icons.search,
    required this.onSelected,
    this.onCleared,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  Timer? _debounce;

  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  bool _fetching = false;
  bool _showList = false;
  bool _programmaticChange = false; // глушить onChanged при програмних змінах

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && mounted && !_fetching) {
      // Затримка щоб onTapDown підказки встиг спрацювати перед закриттям
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focus.hasFocus && !_fetching) {
          setState(() => _showList = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Встановлює текст без тригера onChanged
  void _setCtrlText(String text) {
    _programmaticChange = true;
    _ctrl.text = text;
    _programmaticChange = false;
  }

  void _onChanged(String value) {
    if (_programmaticChange) return;

    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showList = false;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await PlacesService.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showList = results.isNotEmpty;
        _searching = false;
      });
    });
  }

  Future<void> _onTap(PlaceSuggestion suggestion) async {
    _debounce?.cancel();
    setState(() {
      _showList = false;
      _fetching = true;
    });
    _setCtrlText(suggestion.text); // без тригера onChanged

    final details = await PlacesService.getDetails(suggestion.placeId);
    if (!mounted) return;

    if (details != null) {
      _setCtrlText(details.address); // без тригера onChanged
      setState(() => _fetching = false);
      widget.onSelected(details.address, details.lat, details.lng);
    } else {
      // Fallback: зберегти хоча б текст підказки без координат
      setState(() => _fetching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалось отримати координати — спробуйте ще раз'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clear() {
    _debounce?.cancel();
    _setCtrlText('');
    setState(() {
      _suggestions = [];
      _showList = false;
      _searching = false;
    });
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          enabled: !_fetching,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: _fetching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(widget.prefixIcon),
            suffixIcon: _ctrl.text.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clear,
                      ),
                    ],
                  )
                : null,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            isDense: true,
          ),
          onChanged: _onChanged,
        ),
        if (_showList && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                // GestureDetector.onTapDown fires on mousedown (web) — before
                // TextField focus-loss closes the list. Regular onTap fires on
                // mouseup which can arrive AFTER the list is already gone.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    if (!_fetching) _onTap(s);
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.text,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
