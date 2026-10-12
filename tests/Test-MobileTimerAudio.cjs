const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),vm=require('node:vm');
const {chromium}=require(process.argv[2]||'playwright');
const html=fs.readFileSync(path.join(__dirname,'../src/mobile/index.html'),'utf8');
async function main(){
 const ctx={location:{href:'https://example.test/m/fixture/'},URL};vm.createContext(ctx);
 vm.runInContext(html.match(/class TimerAlarm \{[\s\S]*?(?=document.querySelector|const alarm=new TimerAlarm)/)[0]+';globalThis.TimerAlarm=TimerAlarm;',ctx);
 let calls=0;const notices=[],audio={src:'',pause(){},play(){calls++;return Promise.resolve()}};
 const a=new ctx.TimerAlarm(audio,s=>notices.push(s));assert.equal(a.sound,'timer-4');
 a.observe({status:'finished'});assert.equal(calls,0,'No alarm on initial completed session');
 await a.play();a.observe({status:'running'});a.observe({status:'finished'});a.observe({status:'finished'});
 assert.equal(calls,2,'One preview and one completion only');assert(audio.src.endsWith('sounds/timer-4.mp3'));
 a.enabled=false;a.observe({status:'running'});a.observe({status:'finished'});assert.equal(calls,2);
 a.enabled=true;a.observe({status:'running'},'pc');a.observe({status:'finished'},'pc');assert.equal(calls,2,'PC-only suppressed mobile alarm');
 audio.play=()=>Promise.reject(new Error('Autoplay blocked'));a.enabled=true;await a.play();assert.equal(a.armed,false);assert(notices.at(-1).includes('permisos'));
 let phase='idle',output='mobile',permission=false,revision=0;const server=http.createServer((req,res)=>{
  if(req.url.endsWith('/status')){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({modules:['timer'],timerControl:permission,timerAlarm:{output,revision},cores:[],timer:{configured:true,status:phase,baseDuration:60,duration:60,remaining:phase==='finished'?0:50,extraStep:5,revision:1}}))}
  if(req.url.endsWith('/timer')){let body='';req.on('data',v=>body+=v);req.on('end',()=>{const command=JSON.parse(body);assert(permission);assert.equal(req.headers['x-aliengamer-timer'],'1');if(command.action==='alarm'){assert.equal(command.alarmRevision,revision);output=command.output;revision++}else{assert.equal(command.action,'configure');phase='idle'}res.setHeader('Content-Type','application/json');res.end(JSON.stringify({status:phase,configured:true,remaining:50,revision:1}))});return}
  const sound=req.url.match(/\/sounds\/(timer-[1-4]\.mp3)$/);
  if(sound){res.setHeader('Content-Type','audio/mpeg');return res.end(fs.readFileSync(path.join(__dirname,'../src/mobile/sounds',sound[1])))}
  res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:393,height:852}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/m/fixture/`);await page.waitForTimeout(1100);
  await page.locator('#timerConfigure').click();assert.equal(await page.locator('#alarmSound').inputValue(),'timer-4');assert(await page.locator('#timerForm').isHidden());
  assert(await page.locator('#alarmOutput').isDisabled(),'Read-only cannot change shared output');
  await page.locator('#alarmPreview').click();await page.waitForFunction(()=>document.querySelector('#alarmStatus').textContent.includes('habilitado'));
  await page.waitForFunction(()=>document.querySelector('#alarmPreview').textContent==='Detener');await page.locator('#alarmPreview').click();
  assert(await page.evaluate(()=>alarm.audio.paused&&!alarm.playing));assert.equal(await page.locator('#alarmPreview').textContent(),'Activar y probar');
  await page.locator('#alarmPreview').click();await page.waitForFunction(()=>document.querySelector('#alarmPreview').textContent==='Detener');
  await page.waitForFunction(()=>!alarm.audio.paused&&alarm.audio.currentTime>0);
  await page.evaluate(()=>alarm.audio.dispatchEvent(new Event('ended')));assert.equal(await page.locator('#alarmPreview').textContent(),'Activar y probar');await page.evaluate(()=>stopAlarmPreview());
  await page.evaluate(()=>{globalThis.alarmPlays=0;const native=alarm.audio.play.bind(alarm.audio);alarm.audio.play=()=>{globalThis.alarmPlays++;return native()}});
  phase='running';await page.waitForTimeout(1200);phase='finished';await page.waitForTimeout(2400);assert.equal(await page.evaluate(()=>alarmPlays),1);
  permission=true;await page.waitForFunction(()=>!document.querySelector('#alarmOutput').disabled);await page.locator('#alarmOutput').selectOption('pc');await page.waitForFunction(()=>document.querySelector('#alarmOutput').value==='pc'&&!document.querySelector('#alarmOutput').disabled);
  phase='running';await page.waitForTimeout(1200);phase='finished';await page.waitForTimeout(1200);assert.equal(await page.evaluate(()=>alarmPlays),1,'PC-only must not play on mobile');
  await page.locator('#alarmOutput').selectOption('both');await page.waitForFunction(()=>document.querySelector('#alarmOutput').value==='both'&&!document.querySelector('#alarmOutput').disabled);
  phase='running';await page.waitForTimeout(1200);phase='finished';await page.waitForTimeout(1200);assert.equal(await page.evaluate(()=>alarmPlays),2,'Both should play once on mobile');
  await page.locator('#alarmSound').selectOption('custom');await page.locator('#alarmFile').setInputFiles(path.join(__dirname,'../src/mobile/sounds/timer-2.mp3'));
  await page.waitForFunction(()=>document.querySelector('#alarmStatus').textContent.includes('guardado sólo'));await page.reload();
  await page.waitForFunction(()=>document.querySelector('#alarmStatus').textContent.includes('Tu MP3'));assert.equal(await page.locator('#alarmSound').inputValue(),'custom');
  await page.locator('#timerConfigure').click();await page.locator('#alarmPreview').click();await page.waitForFunction(()=>document.querySelector('#alarmStatus').textContent.includes('habilitado'));
  await page.locator('#timerMinutes').fill('1');await page.locator('#timerStep').fill('1');await page.getByRole('button',{name:'Guardar tiempo',exact:true}).click();
  assert(await page.evaluate(()=>alarm.audio.paused&&!alarm.playing),'Save must stop preview');assert.equal(await page.locator('#alarmPreview').textContent(),'Activar y probar');
  const output=path.join(__dirname,'../build/tests');fs.mkdirSync(output,{recursive:true});
  assert(await page.locator('#timerSettings').isHidden(),'Saving closes the unified settings panel');await page.locator('#timerConfigure').click();
  for(const [name,width,height] of [['portrait',393,852],['landscape',852,393]]){await page.setViewportSize({width,height});await page.waitForTimeout(150);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await page.locator('[data-id="timer"]').screenshot({path:path.join(output,`timer-audio-${name}.png`)})}
  assert.deepEqual(errors,[]);console.log('PASS: default sound 4, one-shot expiry, muted/blocked audio, real MP3 playback, persistent custom MP3, read-only controls and responsive layout.');
 }finally{await browser.close();server.closeAllConnections();server.close()}
}
main().catch(e=>{console.error(e);process.exitCode=1});
