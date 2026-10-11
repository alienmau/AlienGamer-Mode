const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(require('node:path').join(__dirname,'../src/mobile/index.html'),'utf8');
const fn=html.match(/function timerColor\(timer\)\{[\s\S]*?\n\}/)[0];
const context={};vm.createContext(context);vm.runInContext(fn,context);
for(const [remaining,color] of [[100,'#19e88b'],[31,'#19e88b'],[30,'#ff9e1c'],[16,'#ff9e1c'],[15,'#ff2b39'],[0,'#ff2b39']]){
 assert.equal(context.timerColor({configured:true,status:'running',duration:100,remaining}),color);
}
assert.equal(context.timerColor({status:'finished'}),'#ff2b39');
assert.equal(context.timerColor({configured:true,status:'paused',duration:100,remaining:25}),'#ff9e1c');
assert.equal(context.timerColor({configured:false,remaining:0}),'#19e88b');
assert.equal(context.timerColor({configured:true,remaining:5}),'#19e88b');
assert.match(html,/transition:color \.3s ease/);
console.log('PASS: timer colors at 70%/85%, finished, paused, legacy data and smooth transition.');
