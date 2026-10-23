export const intervals = [1, 3, 7, 14, 30, 60, 120, 180];
export const defaultPlan = () => ({newPerDay:10, reviewsPerDay:30, order:'mixed', reminderEnabled:false, reminderHour:20, reminderMinute:0});
export const blankDay = () => ({learnedIDs:[], newIDs:[], reviewIDs:[], finishedIDs:[], extraNew:0, extraReviews:0});
const blankMemory = () => ({step:0, relearningRemaining:0, retryAfterSequence:null, hardCount:0, lastOutcome:null, retired:false});
export function blankProgress(){return {version:2, learned:[], reviews:{}, plan:defaultPlan(), days:{}, reviewSequence:0};}
export function itemsOf(course){return course.chapters.flatMap(chapter=>chapter.grammar.flatMap(grammar=>grammar.examples.map((sentence,index)=>({sentence,index,grammar,chapter,id:sentence.id}))));}
export function dayKey(time){const d=new Date(time);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
export function addDays(time,days){const d=new Date(time);d.setHours(0,0,0,0);d.setDate(d.getDate()+days);return d.getTime();}
const isObject = value => value && typeof value==='object' && !Array.isArray(value);
const isInt = (value,min,max=Number.MAX_SAFE_INTEGER) => Number.isSafeInteger(value)&&value>=min&&value<=max;
const complete = r => r.memory?.retired ?? r.stage>=4;
const active = r => r&&!r.mastered&&!complete(r);
const reinforcing = r => (r.memory?.relearningRemaining??0)>0;
const weak = r => reinforcing(r)||r.wrong>=3||(r.memory?.hardCount??0)>=3;
export function validatePlan(p){return isObject(p)&&isInt(p.newPerDay,0,100)&&isInt(p.reviewsPerDay,1,200)&&['mixed','reviewsFirst'].includes(p.order)&&typeof p.reminderEnabled==='boolean'&&isInt(p.reminderHour,0,23)&&isInt(p.reminderMinute,0,59);}
export function validateProgress(value,items){
  const fail=()=>{throw Error('进度文件无法读取，原记录已保留。');};
  if(!isObject(value)||![1,2].includes(value.version)||!Array.isArray(value.learned)||!isObject(value.reviews))fail();
  const ids=new Set(items.map(i=>i.id)), learned=new Set(value.learned);
  if(learned.size!==value.learned.length||value.learned.some(id=>!ids.has(id)))fail();
  for(const [id,r] of Object.entries(value.reviews)){
    const item=items.find(i=>i.id===id);
    if(!item||!isObject(r)||!item.grammar.examples.every(s=>learned.has(s.id))||!isInt(r.stage,0,value.version===1?4:Number.MAX_SAFE_INTEGER)||!isInt(r.wrong,0)||typeof r.mastered!=='boolean'||r.stage>0&&!Number.isFinite(r.anchor)||!r.mastered&&!complete(r)&&!Number.isFinite(r.due))fail();
    if(value.version===2){
      const m=r.memory;
      if(!isObject(m)||!isInt(m.step,0,7)||!isInt(m.relearningRemaining,0,2)||!isInt(m.hardCount,0)||m.retryAfterSequence!==null&&!isInt(m.retryAfterSequence,0)||typeof m.retired!=='boolean'||m.lastOutcome!==null&&!['incorrect','hard','correct','mastered'].includes(m.lastOutcome))fail();
    }
  }
  for(const i of items)if(i.grammar.examples.every(s=>learned.has(s.id))&&!value.reviews[i.id])fail();
  if(value.version===2){
    if(!validatePlan(value.plan)||!isObject(value.days)||!isInt(value.reviewSequence,0))fail();
    for(const day of Object.values(value.days)){
      if(!isObject(day)||!['learnedIDs','newIDs','reviewIDs','finishedIDs'].every(k=>Array.isArray(day[k])&&new Set(day[k]).size===day[k].length)||!isInt(day.extraNew,0)||!isInt(day.extraReviews,0))fail();
      const admitted=new Set([...day.newIDs,...day.reviewIDs]);
      if(day.learnedIDs.some(id=>!ids.has(id))||[...admitted].some(id=>!value.reviews[id])||day.finishedIDs.some(id=>!admitted.has(id))||day.newIDs.some(id=>day.reviewIDs.includes(id)))fail();
    }
  }
  const p=JSON.parse(JSON.stringify(value));
  if(p.version===1){
    for(const r of Object.values(p.reviews))r.memory={...blankMemory(),step:[0,2,3,4,4][r.stage],retired:r.stage>=4};
    Object.assign(p,{version:2,plan:defaultPlan(),days:{},reviewSequence:0});
  }
  return p;
}
export class LearningEngine {
  constructor(course,progress=blankProgress()){
    this.course=course;this.items=itemsOf(course);this.migratedFromV1=progress.version===1;
    this.progress=validateProgress(progress,this.items);
  }
  get next(){return this.items.find(i=>!this.progress.learned.includes(i.id));}
  get learnedCount(){return this.progress.learned.length;}
  get masteredCount(){return Object.values(this.progress.reviews).filter(r=>r.mastered).length;}
  get completedCount(){return Object.values(this.progress.reviews).filter(r=>complete(r)&&!r.mastered).length;}
  get weakCount(){return Object.values(this.progress.reviews).filter(r=>active(r)&&weak(r)).length;}
  get plan(){return this.progress.plan;}
  activity(now=Date.now()){return this.progress.days[dayKey(now)]??blankDay();}
  ready(id,now=Date.now()){
    const r=this.progress.reviews[id];
    return active(r)&&(r.due<=now||reinforcing(r)&&r.memory.retryAfterSequence!==null&&this.progress.reviewSequence>=r.memory.retryAfterSequence);
  }
  pending(now=Date.now()){
    return this.items.filter(i=>{const r=this.progress.reviews[i.id];return active(r)&&(r.due<=now||reinforcing(r));}).sort((a,b)=>{
      const x=this.progress.reviews[a.id],y=this.progress.reviews[b.id];
      return Number(reinforcing(y))-Number(reinforcing(x))||x.due-y.due||Number(weak(y))-Number(weak(x))||this.items.indexOf(a)-this.items.indexOf(b);
    });
  }
  due(now=Date.now()){return this.pending(now).filter(i=>this.ready(i.id,now));}
  scheduled(now=Date.now()){return Object.entries(this.progress.reviews).filter(([id,r])=>active(r)&&!this.ready(id,now)).map(([,r])=>r);}
  selection(now=Date.now()){
    const day=JSON.parse(JSON.stringify(this.activity(now))), admitted=new Set([...day.newIDs,...day.reviewIDs]), candidates=this.pending(now).filter(i=>!admitted.has(i.id));
    day.newIDs.push(...candidates.filter(i=>this.progress.reviews[i.id].anchor===null).slice(0,Math.max(0,this.plan.newPerDay+day.extraNew-day.newIDs.length)).map(i=>i.id));
    day.reviewIDs.push(...candidates.filter(i=>this.progress.reviews[i.id].anchor!==null).slice(0,Math.max(0,this.plan.reviewsPerDay+day.extraReviews-day.reviewIDs.length)).map(i=>i.id));
    return day;
  }
  dailyItems(now=Date.now()){
    const day=this.selection(now),pending=new Set(this.pending(now).map(i=>i.id));
    let fresh=day.newIDs.filter(id=>pending.has(id)),old=day.reviewIDs.filter(id=>pending.has(id));
    const retry=[...fresh,...old].filter(id=>reinforcing(this.progress.reviews[id]));
    fresh=fresh.filter(id=>!retry.includes(id));old=old.filter(id=>!retry.includes(id));
    const result=[...retry];
    if(this.plan.order==='reviewsFirst')result.push(...old,...fresh);
    else while(fresh.length||old.length){result.push(...old.splice(0,2));if(fresh.length)result.push(fresh.shift());}
    return result.map(id=>this.items.find(i=>i.id===id));
  }
  beginDaily(now=Date.now()){this.progress.days[dayKey(now)]=this.selection(now);return this.dailyItems(now);}
  summary(now=Date.now()){
    const day=this.selection(now),all=this.dailyItems(now),ready=all.filter(i=>this.ready(i.id,now)),admitted=new Set([...day.newIDs,...day.reviewIDs]);
    return {learned:day.learnedIDs.length,newDone:day.newIDs.filter(id=>day.finishedIDs.includes(id)).length,reviewDone:day.reviewIDs.filter(id=>day.finishedIDs.includes(id)).length,newTarget:this.plan.newPerDay+day.extraNew,reviewTarget:this.plan.reviewsPerDay+day.extraReviews,newReady:ready.filter(i=>day.newIDs.includes(i.id)).length,reviewReady:ready.filter(i=>day.reviewIDs.includes(i.id)).length,remaining:all.length,reinforcement:all.filter(i=>reinforcing(this.progress.reviews[i.id])).length,overdue:this.due(now).filter(i=>!admitted.has(i.id)).length,nextReadyAt:Math.min(...all.filter(i=>!this.ready(i.id,now)).map(i=>this.progress.reviews[i.id].due))};
  }
  updatePlan(plan){if(!validatePlan(plan))return false;this.progress.plan={...plan};return true;}
  addExtra(now=Date.now()){const day=this.progress.days[dayKey(now)]??=blankDay();day.extraNew+=5;day.extraReviews+=10;}
  learn(id,now=Date.now()){
    const item=this.items.find(i=>i.id===id);if(!item||this.progress.learned.includes(id))return false;
    this.progress.learned.push(id);
    if(item.grammar.examples.every(s=>this.progress.learned.includes(s.id)))for(const s of item.grammar.examples)this.progress.reviews[s.id]??={anchor:null,stage:0,due:now,mastered:false,wrong:0,memory:blankMemory()};
    const day=this.progress.days[dayKey(now)]??=blankDay();day.learnedIDs.push(id);return true;
  }
  grade(id,outcome,now=Date.now()){
    const r=this.progress.reviews[id];if(!this.ready(id,now)||!['correct','hard','incorrect','mastered'].includes(outcome))return false;
    const m=r.memory,sequence=++this.progress.reviewSequence,wasNew=r.anchor===null;
    const retry=(seconds,others)=>{r.due=now+seconds*1000;m.retryAfterSequence=sequence+others;};
    if(outcome==='incorrect'){r.wrong++;m.step=Math.max(0,m.step-2);m.relearningRemaining=2;retry(60,2);}
    else if(outcome==='hard'){
      m.hardCount++;
      if(wasNew||reinforcing(r)){m.relearningRemaining=Math.max(1,m.relearningRemaining);retry(300,2);}
      else{m.step=Math.max(0,m.step-1);r.due=addDays(now,intervals[m.step]);}
    }else if(outcome==='mastered'){r.mastered=true;r.due=null;m.relearningRemaining=0;m.retryAfterSequence=null;}
    else if(m.relearningRemaining>1){m.relearningRemaining--;retry(600,2);}
    else{
      const wasRetry=m.relearningRemaining===1;m.relearningRemaining=0;m.retryAfterSequence=null;
      m.step=wasNew||wasRetry?0:Math.min(intervals.length-1,m.step+1);
      r.anchor??=now;r.stage++;r.due=addDays(now,intervals[m.step]);
    }
    r.last=now;m.lastOutcome=outcome;
    const day=this.progress.days[dayKey(now)]??=blankDay();
    if(!day.newIDs.includes(id)&&!day.reviewIDs.includes(id))(wasNew?day.newIDs:day.reviewIDs).push(id);
    day.finishedIDs=day.finishedIDs.filter(x=>x!==id);if(!reinforcing(r))day.finishedIDs.push(id);
    return true;
  }
}
