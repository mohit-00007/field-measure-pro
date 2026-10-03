import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_api.dart';
import 'razorpay_bridge.dart';

class EntitlementService {
  static const _userIdKey = 'fmp.payment.user_id';
  static const _trialUsedKey = 'fmp.payment.trial_used';

  static Future<String> userId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_userIdKey);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = '${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => r.nextInt(36).toRadixString(36)).join()}';
      await prefs.setString(_userIdKey, id);
    }
    return id;
  }

  static Future<bool> trialUsed() async =>
      (await SharedPreferences.getInstance()).getBool(_trialUsedKey) ?? false;

  /// Marks the one-time free measurement as used.
  ///
  /// IMPORTANT: this must only be called after the user successfully saves
  /// their first measurement. Opening a measurement screen must not consume
  /// the free measurement.
  static Future<void> consumeTrial() async =>
      (await SharedPreferences.getInstance()).setBool(_trialUsedKey, true);

  static Future<bool> hasPremium() async {
    try {
      final status = await PaymentApi.status(userId: await userId());
      return status.active;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureAccess(BuildContext context) async {
    if (await hasPremium()) return true;

    // The free measurement is consumed only after a successful save.
    // Do NOT mark it as used here: merely opening a measurement screen,
    // cancelling, or abandoning a measurement must not consume the trial.
    if (!await trialUsed()) return true;
    if (!context.mounted) return false;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PaywallDialog(),
    ) ?? false;
  }
}

class _PaywallDialog extends StatefulWidget {
  const _PaywallDialog();
  @override State<_PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<_PaywallDialog> {
  final email = TextEditingController();
  String plan = 'monthly';
  bool busy = false;
  String? error;

  @override void initState() { super.initState(); _loadEmail(); }
  Future<void> _loadEmail() async {
    final p = await SharedPreferences.getInstance();
    email.text = p.getString('fmp.payment.email') ?? '';
  }
  @override void dispose() { email.dispose(); super.dispose(); }

  Future<void> _subscribe() async {
    final e = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) { setState(() => error='Enter a valid email address.'); return; }
    setState(() { busy=true; error=null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fmp.payment.email', e);
      final id = await EntitlementService.userId();
      final sub = await PaymentApi.createSubscription(userId:id,email:e,plan:plan);
      final result = await openRazorpayCheckout({...sub,'email':e});
      if (result['cancelled'] == true) { setState(() => busy=false); return; }
      if (result['failed'] == true) throw Exception(result['error']?['description']?.toString() ?? 'Payment failed.');
      final status = await PaymentApi.verifySubscription(
        userId:id,
        paymentId:result['razorpay_payment_id'].toString(),
        subscriptionId:result['razorpay_subscription_id'].toString(),
        signature:result['razorpay_signature'].toString(),
      );
      if (!mounted) return;
      if (status.active) Navigator.pop(context, true);
      else setState(() { busy=false; error='Payment was received but the subscription is not active yet. Please wait a moment and try again.'; });
    } catch (e) {
      if (mounted) setState(() { busy=false; error=e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: const Row(children:[Icon(Icons.workspace_premium,color:Color(0xFF4ADE80)),SizedBox(width:10),Text('Field Measure Pro Premium',style:TextStyle(color:Colors.white,fontSize:18))]),
      content: SizedBox(width:520, child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Your free measurement has been used. Continue with a subscription.',style:TextStyle(color:Colors.white70)),
        const SizedBox(height:16),
        TextField(controller:email,keyboardType:TextInputType.emailAddress,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(labelText:'Email',labelStyle:TextStyle(color:Colors.white70),border:OutlineInputBorder())),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:_plan('monthly','Monthly','₹99 / month','Flexible',plan=='monthly',()=>setState(()=>plan='monthly'))),
          const SizedBox(width:10),
          Expanded(child:_plan('yearly','Yearly','₹990 / year','Save ₹198',plan=='yearly',()=>setState(()=>plan='yearly'))),
        ]),
        const SizedBox(height:14),
        const Text('Recurring payments are handled by Razorpay. UPI AutoPay availability depends on your Razorpay account/payment configuration.',style:TextStyle(color:Colors.white54,fontSize:11)),
        if(error!=null) ...[const SizedBox(height:10),Text(error!,style:const TextStyle(color:Colors.redAccent,fontSize:12))],
      ]))),
      actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),child:const Text('NOT NOW')),ElevatedButton(onPressed:busy?null:_subscribe,style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF16A34A),foregroundColor:Colors.white),child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):Text('CONTINUE WITH ₹${plan=='monthly'?'99':'990'}'))],
    );
  }

  Widget _plan(String id,String title,String price,String note,bool selected,VoidCallback onTap)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:selected?const Color(0xFF14532D):const Color(0xFF1E293B),borderRadius:BorderRadius.circular(12),border:Border.all(color:selected?const Color(0xFF4ADE80):const Color(0xFF334155),width:selected?2:1)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(selected?Icons.radio_button_checked:Icons.radio_button_off,color:selected?const Color(0xFF4ADE80):Colors.white54,size:18),const SizedBox(width:6),Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))]),const SizedBox(height:6),Text(price,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),Text(note,style:const TextStyle(color:Colors.white54,fontSize:11))])));
}
