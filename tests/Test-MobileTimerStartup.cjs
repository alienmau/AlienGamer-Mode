const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require(process.argv[2]||'playwright');
const html=fs.readFileSync(path.join(__dirname,'../src/mobile/index.html'),'utf8');
let state={timestamp:new Date().toISOString(),source:'HWiNFO Shared Memory',modules:['ram','vram','system','temperatures','fps','alerts','clock','timer'],ramUsedMB:12000,ramTotalMB:32000,vramUsed:2400,vramFree:12000,cpuUsage:12,gpuUsage:15,cores:[],timerControl:false,timer:{configured:true,baseDuration:120,duration:120,remaining:120,extraStep:5,extraCount:0,status:'idle',revision:1}};
const commands=[];
const server=http.createServer((req,res)=>{
 res.setHeader('Content-Type',req.url.endsWith('/status')||req.url.endsWith('/timer')?'application/json':'text/html; charset=utf-8');
 if(req.url.endsWith('/status'))return res.end(JSON.stringify(state));
 if(req.url.endsWith('/timer')){let body='';req.on('data',chunk=>body+=chunk);req.on('end',()=>{const v=JSON.parse(body);commands.push(v);assert.equal(req.headers['x-aliengamer-timer'],'1');if(v.revision!==state.timer.revision){res.statusCode=409;return res.end(JSON.stringify({error:'Conflicto de revisión'}))}state.timer={...state.timer,revision:state.timer.revision+1};if(v.action==='configure')Object.assign(state.timer,{baseDuration:v.seconds,duration:v.seconds,remaining:v.seconds,extraStep:v.extraStep,status:'idle'});if(v.action==='start')state.timer.status='running';if(v.action==='pause')state.timer.status='paused';res.end(JSON.stringify(state.timer))});return}
 res.end(html);
});
async function main(){
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const context=await browser.newContext({viewport:{width:393,height:852}}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/m/fixture/`);
  await page.waitForTimeout(1200);
  assert.deepEqual(errors,[],'No JavaScript exception during startup');
  await page.waitForFunction(()=>document.querySelector('#status').textContent.startsWith('En vivo'),{},{timeout:5000});
  assert(await page.locator('[data-id="ram"]').isVisible());assert(await page.locator('#timerPlay').isHidden());assert(await page.locator('#timerConfigure').isVisible());
  await page.locator('#timerConfigure').click();assert(await page.locator('#timerForm').isHidden());assert(await page.locator('#alarmSound').isVisible());assert(await page.locator('#alarmOutput').isDisabled());await page.locator('#timerConfigure').click();
  state.timerControl=true;await page.reload();
  await page.waitForFunction(()=>!document.querySelector('#timerControls').hidden,{},{timeout:5000});
  const card=page.locator('[data-id="timer"]');
  assert.equal(await card.locator('h2').count(),0,'No shared timer heading');
  assert(!(await card.textContent()).includes('Los cambios se aplican'),'No repetitive shared-state legend');
  for(const id of ['timerPlay','timerExtra','timerReset','timerConfigure']){
   const button=page.locator('#'+id);
   assert.equal((await button.textContent()).trim(),'','Icon-only primary controls');
   assert.equal(await button.locator('svg[aria-hidden="true"]').count(),1);
   assert(await button.getAttribute('aria-label'),'Accessible control name');
   assert(await button.getAttribute('title'),'Control tooltip');
   const r=await button.boundingBox();assert(r.width>=44&&r.height>=44,'Touch target at least 44px');
  }
  await page.getByRole('button',{name:'Configurar',exact:true}).click();
  assert(await page.locator('#alarmSound').isVisible(),'Same configuration button opens audio and time');assert.equal(await page.locator('.timer-sound summary').count(),0,'No separate sound disclosure');
  await page.locator('#timerMinutes').fill('3');await page.locator('#timerStep').fill('2');
  await page.getByRole('button',{name:'Guardar tiempo',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('#timer').textContent==='00:03:00');
  assert.equal(commands[0].seconds,180);assert.equal(commands[0].extraStep,2);
  await page.getByRole('button',{name:'Iniciar',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('#timerPlay').getAttribute('aria-label')==='Pausar');
  assert.equal(await page.locator('#timerPlay').getAttribute('data-icon'),'pause');
  await page.getByRole('button',{name:'Pausar',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('#timerState').textContent==='Pausado');
  assert.equal(await page.locator('#timerError').textContent(),'','No success legend');
  assert.equal(await page.locator('#timerPlay').getAttribute('data-icon'),'play');
  const output=path.join(__dirname,'../build/tests');fs.mkdirSync(output,{recursive:true});
  for(const [label,width,height] of [['portrait',393,852],['landscape',852,393]]){
   await page.setViewportSize({width,height});await page.getByRole('button',{name:'Configurar',exact:true}).click();await page.waitForTimeout(100);
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'No horizontal overflow');
   await page.locator('[data-id="timer"]').screenshot({path:path.join(output,`shared-timer-${label}.png`)});
   await page.getByRole('button',{name:'Configurar',exact:true}).click();
   await card.screenshot({path:path.join(output,`shared-timer-icons-${label}.png`)});
  }
  state.timerControl=false;await page.waitForFunction(()=>document.querySelector('#timerPlay').hidden);assert(await page.locator('#timerConfigure').isEnabled());
  assert.deepEqual(errors,[],'No errors through permission changes');
  console.log('PASS: startup, permissions, configure/start/pause, flat accessible icons, 44px targets, removed legends, portrait/landscape.');
  await context.close();
 }finally{await browser.close();server.closeAllConnections();server.close()}
}
main().catch(e=>{console.error(e);server.closeAllConnections();server.close();process.exitCode=1});
