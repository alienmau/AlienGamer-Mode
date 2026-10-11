const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../src/mobile/index.html'),'utf8');
for(const match of html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
for(const id of ['timerControls','timerPlay','timerExtra','timerReset','timerConfigure','timerForm','timerHours','timerMinutes','timerSeconds','timerStep','timerError']){
 if(!html.includes(`id="${id}"`)&&!html.includes(`timerButton('${id}'`))throw new Error('Missing timer control: '+id);
}
if(!html.includes("revision:lastStatus.timer.revision")||!html.includes("'X-AlienGamer-Timer':'1'"))throw new Error('Missing protected request');
console.log('PASS: mobile JavaScript parses, timer controls and protected request wiring present.');
