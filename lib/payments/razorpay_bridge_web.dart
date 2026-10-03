import 'dart:convert';
import 'dart:js_interop';

@JS('startRazorpaySubscription')
external JSPromise<JSString> _startRazorpaySubscription(JSString optionsJson);

Future<Map<String, dynamic>> openRazorpayCheckout(Map<String, dynamic> options) async {
  final result = await _startRazorpaySubscription(jsonEncode(options).toJS).toDart;
  return jsonDecode(result.toDart) as Map<String, dynamic>;
}
