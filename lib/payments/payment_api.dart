import 'dart:convert';
import 'package:http/http.dart' as http;

const fmpApiBaseUrl = String.fromEnvironment('FMP_API_BASE_URL', defaultValue: '');

class SubscriptionStatus {
  final bool active;
  final String status;
  final String? plan;
  final DateTime? currentPeriodEnd;
  const SubscriptionStatus({required this.active, required this.status, this.plan, this.currentPeriodEnd});
}

class PaymentApi {
  static String get _base => fmpApiBaseUrl.replaceFirst(RegExp(r'/$'), '');

  static Future<Map<String, dynamic>> createSubscription({required String userId, required String email, required String plan}) async {
    if (_base.isEmpty) throw Exception('Payment backend is not configured. Set FMP_API_BASE_URL.');
    final r = await http.post(Uri.parse('$_base/api/create-subscription'), headers: {'content-type':'application/json'}, body: jsonEncode({'user_id':userId,'email':email,'plan':plan}));
    final body = jsonDecode(r.body) as Map<String,dynamic>;
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(body['error']?.toString() ?? 'Unable to create subscription');
    return body;
  }

  static Future<SubscriptionStatus> verifySubscription({required String userId, required String paymentId, required String subscriptionId, required String signature}) async {
    if (_base.isEmpty) throw Exception('Payment backend is not configured.');
    final r = await http.post(Uri.parse('$_base/api/verify-subscription'), headers: {'content-type':'application/json'}, body: jsonEncode({'user_id':userId,'razorpay_payment_id':paymentId,'razorpay_subscription_id':subscriptionId,'razorpay_signature':signature}));
    final body = jsonDecode(r.body) as Map<String,dynamic>;
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(body['error']?.toString() ?? 'Payment verification failed');
    return _status(body);
  }

  static Future<SubscriptionStatus> status({required String userId}) async {
    if (_base.isEmpty) return const SubscriptionStatus(active:false,status:'not_configured');
    final r = await http.get(Uri.parse('$_base/api/status?user_id=${Uri.encodeQueryComponent(userId)}'));
    final body = jsonDecode(r.body) as Map<String,dynamic>;
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(body['error']?.toString() ?? 'Subscription status failed');
    return _status(body);
  }

  static SubscriptionStatus _status(Map<String,dynamic> b) => SubscriptionStatus(
    active: b['active'] == true,
    status: b['status']?.toString() ?? 'unknown',
    plan: b['plan']?.toString(),
    currentPeriodEnd: b['current_period_end'] == null ? null : DateTime.tryParse(b['current_period_end'].toString()),
  );
}
