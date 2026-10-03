window.startRazorpaySubscription = function (optionsJson) {
  return new Promise(function (resolve, reject) {
    try {
      const input = JSON.parse(optionsJson);
      const options = {
        key: input.key_id,
        subscription_id: input.subscription_id,
        name: 'Field Measure Pro',
        description: input.plan === 'yearly' ? 'Field Measure Pro — Yearly' : 'Field Measure Pro — Monthly',
        image: '',
        prefill: { email: input.email || '' },
        notes: { product: 'Field Measure Pro', plan: input.plan || '' },
        theme: { color: '#16A34A' },
        modal: { ondismiss: function () { resolve(JSON.stringify({cancelled: true})); } },
        handler: function (response) {
          resolve(JSON.stringify({
            razorpay_payment_id: response.razorpay_payment_id,
            razorpay_subscription_id: response.razorpay_subscription_id,
            razorpay_signature: response.razorpay_signature
          }));
        }
      };
      const rzp = new Razorpay(options);
      rzp.on('payment.failed', function (response) {
        resolve(JSON.stringify({failed: true, error: response.error || {description: 'Payment failed'}}));
      });
      rzp.open();
    } catch (e) {
      reject(e);
    }
  });
};
