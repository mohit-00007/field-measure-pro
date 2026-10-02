import Razorpay from 'razorpay';
const rzp = new Razorpay({key_id:process.env.RAZORPAY_KEY_ID,key_secret:process.env.RAZORPAY_KEY_SECRET});
const plans=[
 {name:'Field Measure Pro Monthly',period:'monthly',interval:1,amount:9900,description:'Field Measure Pro Premium — Monthly'},
 {name:'Field Measure Pro Yearly',period:'yearly',interval:1,amount:99000,description:'Field Measure Pro Premium — Yearly'}
];
for(const p of plans){
 const plan=await rzp.plans.create({period:p.period,interval:p.interval,item:{name:p.name,amount:p.amount,currency:'INR',description:p.description},notes:{product:'Field Measure Pro'}});
 console.log(`${p.period.toUpperCase()}_PLAN_ID=${plan.id}`);
}
