export function blankProgress(){return {version:1,learned:[],reviews:{}};}
export function itemsOf(course){return course.chapters.flatMap(chapter=>chapter.grammar.flatMap(grammar=>grammar.examples.map((sentence,index)=>({sentence,index,grammar,chapter,id:sentence.id}))));}
export function addDays(time,days){const date=new Date(time);date.setDate(date.getDate()+days);return date.getTime();}
export function validateProgress(value,items){if(!value||value.version!==1||!Array.isArray(value.learned)||!value.reviews||typeof value.reviews!=='object'||Array.isArray(value.reviews))throw Error('进度文件无法读取，原记录已保留。');const ids=new Set(items.map(i=>i.id));if(value.learned.some(id=>!ids.has(id))||new Set(value.learned).size!==value.learned.length)throw Error('进度与句库不匹配，原记录已保留。');for(const [id,r]of Object.entries(value.reviews)){const item=items.find(i=>i.id===id);if(!item||!item.grammar.examples.every(s=>value.learned.includes(s.id))||!Number.isInteger(r.stage)||r.stage<0||r.stage>4||r.stage>0&&!Number.isFinite(r.anchor)||!r.mastered&&r.stage<4&&!Number.isFinite(r.due))throw Error('复习记录不完整，原记录已保留。');}for(const item of items)if(item.grammar.examples.every(s=>value.learned.includes(s.id))&&!value.reviews[item.id])throw Error('复习记录不完整，原记录已保留。');return value;}
export class LearningEngine{
 constructor(course,progress=blankProgress()){this.course=course;this.items=itemsOf(course);this.progress=validateProgress(progress,this.items);}
 get next(){return this.items.find(i=>!this.progress.learned.includes(i.id));}
 get learnedCount(){return this.progress.learned.length;}
 get masteredCount(){return Object.values(this.progress.reviews).filter(r=>r.mastered).length;}
 due(now=Date.now()){return this.items.filter(i=>{const r=this.progress.reviews[i.id];return r&&!r.mastered&&r.stage<4&&r.due<=now;});}
 scheduled(now=Date.now()){return Object.values(this.progress.reviews).filter(r=>!r.mastered&&r.stage<4&&r.due>now);}
 learn(id,now=Date.now()){const item=this.items.find(i=>i.id===id);if(!item||this.progress.learned.includes(id))return false;this.progress.learned.push(id);if(item.grammar.examples.every(s=>this.progress.learned.includes(s.id)))for(const s of item.grammar.examples)this.progress.reviews[s.id]??={anchor:null,stage:0,due:now,mastered:false,wrong:0};return true;}
 grade(id,outcome,now=Date.now()){const r=this.progress.reviews[id];if(!r||r.mastered||r.stage>=4||r.due>now||!['correct','incorrect','mastered'].includes(outcome))return false;if(outcome==='incorrect'){r.wrong++;return true;}if(outcome==='mastered'){r.mastered=true;r.due=null;return true;}r.anchor??=now;r.stage++;r.due=r.stage===4?null:addDays(r.anchor,[7,14,30][r.stage-1]);return true;}
}
