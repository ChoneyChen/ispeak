import {LearningEngine, blankProgress} from './engine.mjs';
const key='ispeak.general.v1', app=document.getElementById('app'), tabs=document.getElementById('tabs');
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let engine,tab='study',session=null,queue=[],revealed=false,busy=false,sectionDone=null,initial=0,passed=0,cut=0,preview=null,chapter=null,supplement=null,query='',readOnly=false,deferredInstall,waiting=false,feedback='',sessionDay='';
const primary=(text,action)=>`<button class="primary" data-action="${action}">${text}<span aria-hidden="true">→</span></button>`;
function banner(message){const el=document.getElementById('save-error');el.hidden=!message;el.textContent=message||'';}
function persist(){if(readOnly)return;try{localStorage.setItem(key,JSON.stringify(engine.progress));banner('');}catch{banner('本次进度暂未保存，请检查设备存储空间；当前练习仍可继续。');}}
let toastTimer;
function toast(message){const el=document.getElementById('toast');el.textContent=message;el.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('show'),2600);}
function home(){
  const item=engine.next,s=engine.summary();
  return `<div class="top-row"><a class="brand" href="../"><img src="../assets/favicon.svg" alt="">句屿</a><button class="pill" data-action="install">安装到主屏幕</button></div>
  <div><h1>把句子，<br>说成自己的。</h1><p class="sub">一次一句。先看懂，再开口。</p></div>
  <section class="hero-card"><div class="top-row"><span class="mini">${engine.learnedCount?'接着上次的进度':'从第一句开始'}</span><span class="mini" id="learned-count">${engine.learnedCount} / ${engine.items.length}</span></div><h2>${item?esc(item.chapter.shortTitle):'全部学过了。'}</h2><p class="mini">${item?esc(item.grammar.title):'去背诵，让句子慢慢留下来。'}</p><div class="progress"><i style="width:${engine.learnedCount/engine.items.length*100}%"></i></div>${item?primary(engine.learnedCount?'继续学习':'开始学习','start-learn'):primary('去背诵','to-recall')}</section>
  <div class="stats"><div><b>${engine.learnedCount}</b><span>已学习</span></div><div><b>${engine.due().length}</b><span>待背诵</span></div><div><b>${engine.course.chapters.reduce((n,c)=>n+c.grammar.length,0)}</b><span>语法点</span></div></div>
  <div class="routes">${[1,2,3].map((p,i)=>`<button class="route" data-action="part" data-id="${p}"><b>${['☀','♧','✳'][i]}</b><div><strong>${['日常问答','讲述经历','表达观点'][i]}</strong></div><small>${['身份、家乡与习惯','把故事说清楚','让想法更有层次'][i]}</small><span>›</span></button>`).join('')}</div>
  <p class="home-note">今天已新学 ${s.learned} / ${s.newTarget} 句 · 目标之外也能继续学</p>`;
}
function recallHome(){
  const s=engine.summary(),hasLearned=Object.keys(engine.progress.reviews).length>0;
  const row=(name,value,max)=>`<div class="plan-progress"><span>${name}</span><div class="progress"><i style="width:${max?Math.min(100,value/max*100):100}%"></i></div><small>${value} / ${max}</small></div>`;
  return `<div class="top-row"><h3>今日背诵</h3><button class="round" data-action="plan" aria-label="每日计划">☷</button></div>
  <div><h1>每天几句，<br>慢慢记牢。</h1><p class="sub">新句和旧句一起练，难记的多见几次。</p></div>
  <section class="daily-card"><div class="due-title"><b>${s.remaining}</b><span>句 · 今天的安排</span><i aria-hidden="true">♧</i></div><div class="daily-counts"><div><b>${s.newReady}</b><span>新句初背</span></div><div><b>${s.reviewReady}</b><span>到期复习</span></div><div><b>${s.reinforcement}</b><span>需要加强</span></div></div>
  ${s.remaining?primary(s.newReady+s.reviewReady?'开始今日背诵':'继续巩固','start-recall'):engine.next&&s.learned<s.newTarget?`<p class="mini">${hasLearned?'再学一节，给今天添几句新表达。':'背诵库还在等第一节'}</p>${primary('去学几句','to-study')}`:`<p class="done-note">✓ 今天的计划，完成了</p>${s.overdue?primary('再练一小组','extra'):''}`}</section>
  <section class="daily-progress"><div class="top-row"><strong>今天的进度</strong><button class="inline-button" data-action="plan">调整计划</button></div>${row('新学',s.learned,s.newTarget)}${row('初背',s.newDone,s.newTarget)}${row('复习',s.reviewDone,s.reviewTarget)}${s.overdue?`<p class="backlog">另有 ${s.overdue} 句待练，会保留到下次，也可以加练。</p>`:''}</section>
  <p class="daily-tip">✳ 背错先理解，隔开再回忆。记得越牢，下次见面的间隔越长。</p><button class="inline-button guide-button" data-action="review-guide">背诵怎么安排？</button>`;
}
function library(){if(supplement){const s=engine.course.supplements.find(s=>s.id===supplement);return `<div class="top-row"><button class="round" data-action="library-back" aria-label="返回句库">‹</button><span class="eyebrow">FIELD GUIDE</span></div><h2>${esc(s.title)}</h2><p class="sub">${esc(s.subtitle)}</p><div class="supplement">${esc(s.body)}</div>`;}let found=query.trim()?engine.items.filter(i=>[i.sentence.en,i.sentence.zh,i.grammar.title,i.grammar.id].some(t=>t.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()))):[];return `<div class="top-row"><h2>句库</h2><span class="eyebrow">700 SENTENCES</span></div><input class="search" type="search" id="search" value="${esc(query)}" placeholder="搜索中文、英文或语法编号" aria-label="搜索句库">${query.trim()?`<p class="mini">找到 ${found.length} 个例句</p>${found.map(i=>`<button class="search-result" data-action="preview" data-id="${i.id}"><span class="eyebrow">${i.grammar.id} · ${esc(i.chapter.shortTitle)}</span><p class="en">${esc(i.sentence.en)}</p><p class="zh">${esc(i.sentence.zh)}</p></button>`).join('')||'<p class="sub">换个关键词试试看。</p>'}`:`${(chapter?engine.course.chapters.filter(c=>c.id===chapter):engine.course.chapters).map(c=>`<button class="route" data-action="chapter" data-id="${c.id}"><b>${String(c.id).padStart(2,'0')}</b><div><strong>${esc(c.shortTitle)}</strong><small>PART ${c.part} · ${esc(c.title)}</small></div><span>${chapter?'−':'›'}</span></button>${chapter?c.grammar.map(g=>`<button class="search-result" data-action="preview" data-id="${g.examples[0].id}"><span class="eyebrow">${g.id} / ${esc(g.level)}</span><p>${esc(g.title)}</p><small class="mini">${esc(g.pattern)}</small></button>`).join(''):''}`).join('')}<div class="section-title"><h3>随手查阅</h3><small>FIELD GUIDE</small></div>${engine.course.supplements.map(s=>`<button class="route" data-action="supplement" data-id="${s.id}"><div><strong>${esc(s.title)}</strong><small>${esc(s.subtitle)}</small></div><span>›</span></button>`).join('')}`}`;}
function grammarCard(item){
  const g=item.grammar,s=item.sentence;
  return `<div class="top-row"><span class="card-label">语法要点</span><span class="level">${esc(g.level)}</span></div><h3>${esc(g.title)}</h3><p class="pattern">${esc(g.pattern)}</p><p class="note">${esc(g.note)}</p><hr><div class="top-row"><span class="scenario">情境练习</span><button class="sound" data-action="speak" aria-label="朗读英文">◖))</button></div><p class="en" id="english-sentence">${esc(s.en)}</p><p class="zh">${esc(s.zh)}</p>`;
}
function pendingQueue(){return queue.filter(id=>{const r=engine.progress.reviews[id];return r&&!r.mastered&&!r.memory.retired&&(r.memory.relearningRemaining>0||engine.ready(id));});}
function currentItem(){return preview?engine.items.find(i=>i.id===preview):session==='learn'?engine.next:engine.items.find(i=>i.id===pendingQueue().find(id=>engine.ready(id)));}
function sessionView(){
  waiting=false;
  if(sectionDone)return `<div class="top-row"><button class="round" data-action="exit" aria-label="退出学习">×</button><strong>学习完成</strong></div><div class="completion"><div class="stamp">✓</div><h2>这一节，学会了。</h2><p>${esc(sectionDone.title)}</p><p>${sectionDone.examples.length} 个例句已加入背诵库。<br>先用中文提示，试着说出来。</p></div>${primary(engine.next?'继续下一节':'完成全部学习','continue-section')}<button class="text-button" data-action="finish-section">先去背诵</button>`;
  const item=currentItem(),pending=session==='recall'?pendingQueue():[];
  if(!item){
    if(pending.length){
      waiting=true;const next=Math.min(...pending.map(id=>engine.progress.reviews[id].due));
      return `<div class="top-row"><button class="round" data-action="exit" aria-label="退出背诵">×</button><strong>还有 ${pending.length} 句需要加强</strong></div><div class="completion"><div class="stamp">♧</div><h2>留一点间隔，再试一次。</h2><p>这些句子已保留，不会算作完成。</p><p class="retry-time">约 ${Math.max(1,Math.ceil((next-Date.now())/60000))} 分钟后可继续</p></div>${primary('稍后继续','exit')}`;
    }
    return `<div class="top-row"><button class="round" data-action="exit" aria-label="退出背诵">×</button><strong>背诵完成</strong></div><div class="completion"><div class="stamp">✓</div><h2>这一轮，完成了。</h2><p>背对 ${passed} 句${cut?` · 斩掉 ${cut} 句`:''}</p><p>已按记忆情况，安排下一次复习。</p></div>${primary('收好今天的进步','exit')}`;
  }
  const recall=session==='recall',r=engine.progress.reviews[item.id];
  const kind=recall?(r.memory.relearningRemaining?'加强':r.anchor===null?'初背':'复习'):'';
  return `<div class="top-row"><button class="round" data-action="exit" aria-label="${recall?'退出背诵':preview?'退出预览':'退出学习'}">×</button><div><strong>${recall?'开口，再揭晓':esc(item.chapter.shortTitle)} ${recall?`<small class="kind">${kind}</small>`:''}</strong><span class="mini">${recall?`剩余 ${pending.length} 句`:preview?'句库预览 · 不计入学习进度':'一次学会一个结构'}</span></div><span class="mini">${recall?`${passed+cut} / ${initial}`:''}</span></div>
  ${recall?`<div class="progress"><i style="width:${initial?Math.min(100,(passed+cut)/initial*100):0}%"></i></div>`:`<div class="segments">${item.grammar.examples.map((_,i)=>`<i class="${i<=item.index?'filled':''}"></i>`).join('')}</div>`}
  <article class="card ${recall?'recall-card':''}" id="sentence-card">${recall?`<div class="top-row"><span class="card-label">${revealed?'核对表达':'只看中文，试着说出来'}</span><span class="mini" aria-hidden="true">${revealed?'◉':'○'}</span></div><p class="recall-cue ${revealed?'revealed':''}" id="chinese-cue">${esc(item.sentence.zh)}</p>${revealed?`<hr><p class="en" id="answer">${esc(item.sentence.en)}</p><div class="top-row"><button class="inline-button" data-action="grammar-details">看语法 ↗</button><button class="sound" data-action="speak" aria-label="朗读答案">◖))</button></div>`:'<p class="recall-note">不必赶时间，先把意思完整说出来。</p>'}`:grammarCard(item)}</article>
  <div class="session-actions">${recall?`<p class="helper">${esc(feedback||(revealed?'意思准确、语法正确，就算背对。':'先完整说出英文，再看答案。'))}</p>${revealed?'<div class="grade-buttons"><button class="wrong" data-action="grade" data-outcome="incorrect">↶ 背错了</button><button class="hard" data-action="grade" data-outcome="hard">有点难</button><button class="correct" data-action="grade" data-outcome="correct">✓ 正确</button></div><button class="mastered" data-action="grade" data-outcome="mastered">斩 · 已熟练，永久移出</button>':`${primary('查看答案','reveal')}<div class="action-reserve" aria-hidden="true"></div>`}`:preview?`<div class="top-row"><button class="round" data-action="preview-prev" aria-label="上一句" ${item.index===0?'disabled':''}>←</button><span class="mini">${item.index+1} / ${item.grammar.examples.length}</span><button class="round" data-action="preview-next" aria-label="下一句" ${item.index===item.grammar.examples.length-1?'disabled':''}>→</button></div>`:`<div class="card-footer"><span>本节第 ${item.index+1} / ${item.grammar.examples.length} 句</span><span>← 向左轻扫</span></div>${primary(item.index===item.grammar.examples.length-1?'学完这节':'下一句','next')}`}</div>`;
}
function render(){
  const inSession=!!session||!!preview;
  app.classList.toggle('session',inSession);app.classList.toggle('fixed-page',!inSession&&tab!=='library');tabs.hidden=inSession;
  app.innerHTML=inSession?sessionView():tab==='study'?home():tab==='recall'?recallHome():library();
  document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
  requestAnimationFrame(()=>{const card=document.getElementById('sentence-card');if(card&&card.scrollHeight>card.clientHeight+1)card.classList.add('compact');});
}
function transition(mutate){
  busy=true;document.getElementById('sentence-card')?.classList.add('leaving');
  setTimeout(()=>{mutate();busy=false;render();},matchMedia('(prefers-reduced-motion: reduce)').matches?0:150);
}
function learnNext(){
  if(busy||session!=='learn'||sectionDone)return;
  const item=engine.next;if(!item)return;engine.learn(item.id);persist();
  transition(()=>{if(item.index===item.grammar.examples.length-1)sectionDone=item.grammar;});
}
function changeTab(next){if(busy)return;window.speechSynthesis?.cancel();tab=next;session=null;preview=null;sectionDone=null;chapter=null;supplement=null;query='';waiting=false;render();window.scrollTo(0,0);}
function beginRecall(){queue=engine.beginDaily().map(i=>i.id);persist();initial=queue.length;passed=0;cut=0;revealed=false;feedback='';session='recall';sessionDay=new Date().toDateString();render();}
function showPlan(){
  const form=document.getElementById('plan-form');form.elements.new.value=engine.plan.newPerDay;form.elements.reviews.value=engine.plan.reviewsPerDay;form.elements.order.value=engine.plan.order;
  document.getElementById('plan-dialog').showModal();
}
document.addEventListener('click',async event=>{
  const btn=event.target.closest('[data-action],[data-tab]');if(!btn||btn.disabled||busy)return;
  if(btn.dataset.tab){changeTab(btn.dataset.tab);return;}
  const action=btn.dataset.action;
  if(session==='recall'&&sessionDay!==new Date().toDateString()){resume();return;}
  if(action==='start-learn'){session='learn';sectionDone=null;render();}
  else if(action==='next')learnNext();
  else if(action==='continue-section'){sectionDone=null;if(!engine.next)session=null;render();}
  else if(action==='finish-section'||action==='to-recall')changeTab('recall');
  else if(action==='to-study')changeTab('study');
  else if(action==='exit'){window.speechSynthesis?.cancel();session=null;preview=null;sectionDone=null;waiting=false;render();}
  else if(action==='start-recall')beginRecall();
  else if(action==='extra'){engine.addExtra();beginRecall();}
  else if(action==='reveal'){revealed=true;feedback='';render();}
  else if(action==='grade'&&session==='recall'&&revealed){
    const item=currentItem();if(!item)return;
    const id=item.id,outcome=btn.dataset.outcome;if(!engine.grade(id,outcome))return;
    persist();window.speechSynthesis?.cancel();
    transition(()=>{
      queue=queue.filter(x=>x!==id);
      if(engine.progress.reviews[id].memory.relearningRemaining>0){queue.splice(Math.min(2,queue.length),0,id);feedback=outcome==='incorrect'?'这句会隔开再测两次，先试下一句。':'这句还不够熟，稍后再试。';}
      else if(outcome==='mastered'){cut++;feedback='已斩，不再自动复习。';}
      else{passed++;feedback=outcome==='hard'?'已缩短下次复习的间隔。':'已安排下一次复习。';}
      revealed=false;
    });
  }else if(action==='plan')showPlan();
  else if(action==='close-plan')document.getElementById('plan-dialog').close();
  else if(action==='review-guide')document.getElementById('review-guide').showModal();
  else if(action==='close-guide')document.getElementById('review-guide').close();
  else if(action==='grammar-details'){
    const item=currentItem();if(!item||!revealed)return;
    document.getElementById('grammar-content').innerHTML=`<h2>${esc(item.grammar.title)}</h2><p class="pattern">${esc(item.grammar.pattern)}</p><p>${esc(item.grammar.note)}</p><p class="en">${esc(item.sentence.en)}</p><p>${esc(item.sentence.zh)}</p>`;
    document.getElementById('grammar-dialog').showModal();
  }else if(action==='close-grammar')document.getElementById('grammar-dialog').close();
  else if(action==='chapter'){chapter=chapter===+btn.dataset.id?null:+btn.dataset.id;render();}
  else if(action==='part'){tab='library';chapter=engine.course.chapters.find(c=>c.part===+btn.dataset.id)?.id;render();window.scrollTo(0,0);}
  else if(action==='preview'){preview=btn.dataset.id;render();}
  else if(action.startsWith('preview-')){const item=engine.items.find(i=>i.id===preview),delta=action==='preview-next'?1:-1;preview=item.grammar.examples[item.index+delta]?.id||preview;window.speechSynthesis?.cancel();render();}
  else if(action==='supplement'){supplement=btn.dataset.id;render();window.scrollTo(0,0);}
  else if(action==='library-back'){supplement=null;render();}
  else if(action==='speak'){
    const item=currentItem();if(!item||session==='recall'&&!revealed)return;
    if(!('speechSynthesis' in window)){toast('此浏览器暂不支持朗读。');return;}
    speechSynthesis.cancel();const utterance=new SpeechSynthesisUtterance(item.sentence.en);utterance.lang='en-GB';utterance.rate=.85;speechSynthesis.speak(utterance);
  }else if(action==='install'){if(deferredInstall){await deferredInstall.prompt();deferredInstall=null;}else document.getElementById('install-dialog').showModal();}
  else if(action==='close-install')document.getElementById('install-dialog').close();
  else if(action==='export'){
    const blob=new Blob([JSON.stringify(engine.progress,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='ispeak-progress.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }
});
document.getElementById('plan-form').addEventListener('submit',event=>{
  event.preventDefault();const form=event.currentTarget;
  if(engine.updatePlan({...engine.plan,newPerDay:Number(form.elements.new.value),reviewsPerDay:Number(form.elements.reviews.value),order:form.elements.order.value})){
    persist();document.getElementById('plan-dialog').close();render();toast('每日计划已保存。');
  }
});
let searchTimer;
document.addEventListener('input',event=>{
  if(event.target.id==='search'){
    query=event.target.value;clearTimeout(searchTimer);
    searchTimer=setTimeout(()=>{const start=event.target.selectionStart,end=event.target.selectionEnd;render();const input=document.getElementById('search');input?.focus({preventScroll:true});try{input?.setSelectionRange(start,end);}catch{}},220);
  }
});
let dragStart;
document.addEventListener('pointerdown',event=>{if(session==='learn'&&!preview&&event.target.closest('#sentence-card')&&!event.target.closest('button'))dragStart={x:event.clientX,y:event.clientY};});
document.addEventListener('pointercancel',()=>dragStart=null);
document.addEventListener('pointerup',event=>{if(dragStart){const dx=event.clientX-dragStart.x,dy=event.clientY-dragStart.y;if(dx< -75&&Math.abs(dx)>Math.abs(dy))learnNext();dragStart=null;}});
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();deferredInstall=event;});
function resume(){if(!engine)return;if(session==='recall'&&sessionDay!==new Date().toDateString()){session=null;toast('新的一天，按今天的计划继续。');}if(!busy)render();}
document.addEventListener('visibilitychange',()=>{if(!document.hidden)resume();});
setInterval(()=>{if(engine&&waiting&&!document.hidden&&!busy)resume();},1000);
try{
  const res=await fetch('../assets/general-curriculum.json');if(!res.ok)throw Error('句库暂时无法加载，请联网后重试。');
  const course=await res.json();let raw;
  try{raw=localStorage.getItem(key);engine=new LearningEngine(course,raw?JSON.parse(raw):blankProgress());}
  catch{readOnly=true;engine=new LearningEngine(course);banner('已保存的进度暂时无法读取，原记录已保留；本次练习不会覆盖它。');}
  if(engine.migratedFromV1&&!readOnly){
    try{const previous=localStorage.getItem(`${key}.before-v2`);if(previous!==raw)localStorage.setItem(previous===null?`${key}.before-v2`:`${key}.before-v2.${Date.now()}`,raw);persist();}
    catch{readOnly=true;banner('旧进度已读取，但暂时无法备份；本次练习不会覆盖原记录。');}
  }
  render();
  if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
}catch(error){app.innerHTML=`<h2>句库暂时无法打开</h2><p class="sub">${esc(error.message)}</p><a href="./">重新打开 →</a>`;}
