import 'dart:convert';
import 'dart:html' as html;

class PlaceSearchBridge {
  PlaceSearchBridge(this.onSelected);
  final void Function(double latitude, double longitude, String name, String address) onSelected;
  html.EventListener? _listener;

  void initialize() {
    _listener = (html.Event event) {
      final message = event as html.MessageEvent;
      final data = message.data;
      if (data is! String) return;
      if (!data.startsWith('fieldmeasure-place:')) return;
      try {
        final json = jsonDecode(data.substring('fieldmeasure-place:'.length));
        if (json is Map && json['lat'] is num && json['lng'] is num) {
          onSelected(
            (json['lat'] as num).toDouble(),
            (json['lng'] as num).toDouble(),
            (json['name'] ?? 'Selected place').toString(),
            (json['address'] ?? '').toString(),
          );
        }
      } catch (_) {}
    };
    html.window.addEventListener('message', _listener);
  }

  void dispose() {
    final listener = _listener;
    if (listener != null) html.window.removeEventListener('message', listener);
    _listener = null;
  }
}
