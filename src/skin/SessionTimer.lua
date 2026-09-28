-- Per-display timer: wall-clock state survives Rainmeter refreshes.
local state={baseDuration=1800,extraStep=5,extraCount=0,duration=1800,remaining=1800,deadline=0,status="idle",configured=false}
local statePath,enabled,language
local frame,noticeUntil,lastZone=0,0,-1
local digits={Hours=nil,Minutes=nil,Seconds=nil}
local rolling={Hours=nil,Minutes=nil,Seconds=nil}
local hover={Play=0,Extra=0,End=0}
local hoverHold={Play=0,Extra=0,End=0}
local playActionEnabled=nil
local displayProgress,progressVelocity=0,0
local colorZone,colorStep=0,3
local colorFrom,colorTo,colorCurrent={25,232,139},{25,232,139},{25,232,139}

local function clamp(value,lo,hi) return math.max(lo,math.min(hi,value)) end
local function set(meter,option,value) SKIN:Bang("!SetOption",meter,option,tostring(value)) end
local function resetDigits()
    digits={Hours=nil,Minutes=nil,Seconds=nil}
    rolling={Hours=nil,Minutes=nil,Seconds=nil}
    lastZone=-1
end
local function readState()
    local file=io.open(statePath,"r")
    if not file then return nil end
    local data=file:read("*a")
    file:close()
    local loaded={}
    for key,value in data:gmatch("([%a]+)=([^\r\n]+)") do loaded[key]=value end
    local base=tonumber(loaded.baseDuration) or tonumber(loaded.duration)
    local duration=tonumber(loaded.duration)
    local step=tonumber(loaded.extraStep) or 5
    local count=tonumber(loaded.extraCount) or 0
    if not base or not duration or base<60 or duration<base or duration>359999 or
       step<1 or step>30 or count<0 or count>3 then return nil end
    return {baseDuration=math.floor(base),extraStep=math.floor(step),extraCount=math.floor(count),
        duration=math.floor(duration),remaining=clamp(math.floor(tonumber(loaded.remaining) or duration),0,duration),
        deadline=math.floor(tonumber(loaded.deadline) or 0),
        status=({idle=true,running=true,paused=true,finished=true})[loaded.status] and loaded.status or "idle",
        configured=loaded.configured=="1" or (loaded.configured==nil and loaded.status~=nil)}
end
local function saveState()
    local file=io.open(statePath,"w")
    if not file then return end
    file:write(string.format("baseDuration=%d\nextraStep=%d\nextraCount=%d\nduration=%d\nremaining=%d\ndeadline=%d\nstatus=%s\nconfigured=%d\n",
        state.baseDuration,state.extraStep,state.extraCount,state.duration,state.remaining,state.deadline,state.status,
        state.configured and 1 or 0))
    file:close()
end
function Initialize()
    local id=SELF:GetOption("ConfigId","principal"):gsub("[^%w_-]","-")
    statePath=(os.getenv("LOCALAPPDATA") or ".").."\\AlienGamerMode\\session-timer-"..id..".txt"
    enabled=tonumber(SELF:GetOption("Enabled","0"))==1
    language=SELF:GetOption("Language","es-MX")
    local loaded=readState()
    if loaded then
        state=loaded
        -- A Rainmeter refresh or a fresh monitor launch starts a new session,
        -- while the chosen duration and extra-step remain available.
        state.status,state.deadline,state.extraCount="idle",0,0
        state.duration,state.remaining=state.baseDuration,state.baseDuration
        saveState()
    end
end
function StartPause()
    state=readState() or state
    if not state.configured then return end
    if state.status=="running" then
        state.remaining=clamp(state.deadline-os.time(),0,state.duration)
        state.status=state.remaining>0 and "paused" or "finished"
        state.deadline=0
    else
        if state.status=="finished" then
            state.duration,state.remaining,state.extraCount=state.baseDuration,state.baseDuration,0
            displayProgress,progressVelocity=0,0
            resetDigits()
        end
        state.deadline=os.time()+state.remaining
        state.status="running"
    end
    saveState()
end
function EndTimer()
    state.status,state.deadline,state.extraCount="idle",0,0
    state.duration,state.remaining=state.baseDuration,state.baseDuration
    noticeUntil=0
    displayProgress,progressVelocity=0,0
    resetDigits()
    saveState()
end
function AddTime()
    state=readState() or state
    if not state.configured then return end
    if state.extraCount>=3 then return end
    local seconds=state.extraStep*60
    if state.duration+seconds>359999 then return end
    state.extraCount=state.extraCount+1
    state.duration,state.remaining=state.duration+seconds,state.remaining+seconds
    if state.status=="running" then state.deadline=state.deadline+seconds end
    if state.status=="finished" then state.status="paused" end
    noticeUntil=frame+24
    saveState()
end
local function updateDigits(rgb,zone)
    local r,g,b=rgb:match("(%d+),(%d+),(%d+)")
    r,g,b=tonumber(r),tonumber(g),tonumber(b)
    local muted=string.format("%d,%d,%d,225",math.floor(65+r*0.38),math.floor(88+g*0.38),math.floor(85+b*0.38))
    local values={Hours=math.floor(state.remaining/3600),
        Minutes=math.floor(state.remaining/60)%60,Seconds=state.remaining%60}
    for _,name in ipairs({"Hours","Minutes","Seconds"}) do
        local value=values[name]
        if digits[name]==nil then
            digits[name]=value
            set("Timer"..name,"Text",string.format("%02d",value))
        elseif digits[name]~=value then
            rolling[name]={old=digits[name],step=0}
            digits[name]=value
        end
        local animation=rolling[name]
        local main="Timer"..name
        local before=main.."GhostBefore"
        local after=main.."GhostAfter"
        local wrap=name=="Hours" and 100 or 60
        if animation then
            animation.step=math.min(animation.step+1,9)
            local t=animation.step/9
            local ease=t*t*(3-2*t)
            local flash=math.sin(math.pi*t)^2
            local digitColor=string.format("%d,%d,%d,%d",
                math.floor(clamp(65+r*0.38+flash*125,0,255)),
                math.floor(clamp(88+g*0.38+flash*110,0,255)),
                math.floor(clamp(85+b*0.38+flash*125,0,255)),
                math.floor(170+85*flash))
            set(main,"Text",string.format("%02d",value))
            set(main,"Y",math.floor(406+24*ease))
            set(main,"FontSize",string.format("%.1f",11+18*ease))
            set(main,"FontColor",digitColor)
            set(before,"Text",string.format("%02d",(value+wrap-1)%wrap))
            set(before,"Y",math.floor(392+14*ease))
            set(before,"FontSize",string.format("%.1f",9+2*ease))
            set(before,"FontColor",string.format("120,175,175,%d",math.floor(45+45*ease)))
            set(after,"Text",string.format("%02d",animation.old))
            set(after,"Y",math.floor(430+25*ease))
            set(after,"FontSize",string.format("%.1f",29-18*ease))
            set(after,"FontColor",string.format("%d,%d,%d,%d",
                math.floor(65+r*0.38),math.floor(88+g*0.38),math.floor(85+b*0.38),
                math.floor(225-135*ease)))
            if animation.step>=9 then
                rolling[name]=nil
                set(main,"FontColor",muted)
                set(after,"Text",string.format("%02d",(value+1)%wrap))
                set(before,"FontColor","120,175,175,90")
                set(after,"FontColor","120,175,175,90")
            end
        elseif zone~=lastZone or frame==1 then
            set(main,"Text",string.format("%02d",value))
            set(main,"Y",430)
            set(main,"FontSize",29)
            set(main,"FontColor",muted)
            set(before,"Text",string.format("%02d",(value+wrap-1)%wrap))
            set(before,"Y",406)
            set(before,"FontSize",11)
            set(before,"FontColor","120,175,175,90")
            set(after,"Text",string.format("%02d",(value+1)%wrap))
            set(after,"Y",455)
            set(after,"FontSize",11)
            set(after,"FontColor","120,175,175,90")
        end
    end
    lastZone=zone
end
local function renderButton(name,color)
    local target=tonumber(SKIN:GetVariable("Timer"..name.."Hover","0")) or 0
    if name=="Play" and not state.configured then target=0 end
    if target>0 then hoverHold[name]=frame+30 end
    local held=target>0 or frame<hoverHold[name]
    hover[name]=hover[name]+((held and 1 or 0)-hover[name])*0.22
    local level=hover[name]
    local pulse=(math.sin(frame*0.22)+1)/2
    local opacity=(name=="Play" and not state.configured) and 0.35 or (0.60+0.40*level)
    local button="Timer"..name.."Button"
    local fill=name=="Play" and "5,36,44" or (name=="Extra" and "12,28,42" or "38,20,30")
    set(button,"Shape",string.format(
        "Ellipse 23,23,19,19 | Fill Color %s,%d | StrokeWidth 2 | Stroke Color %s,%d",
        fill,math.floor(242*opacity),color,math.floor(230*opacity)))
    local radius=20+level*7
    set("Timer"..name.."Button","Shape2",string.format(
        "Ellipse 23,23,%.1f,%.1f | Fill Color 0,0,0,0 | StrokeWidth 1.4 | Stroke Color %s,%d",
        radius,radius,color,math.floor(level*(120-55*pulse))))
    set("Timer"..name.."Button","Shape3",string.format(
        "Ellipse 23,23,%.1f,%.1f | Fill Color 0,0,0,0 | StrokeWidth 1 | Stroke Color %s,%d",
        radius+4+pulse*4,radius+4+pulse*4,color,math.floor(level*(70-35*pulse))))
    if name=="Play" then
        set("TimerPlayIcon","Shape",string.format(
            "Path PlayTriangle | Fill Color 115,255,190,%d | StrokeWidth 0",math.floor(255*opacity)))
        for _,shape in ipairs({"Shape","Shape2"}) do
            local x=shape=="Shape" and 18 or 25
            set("TimerPauseIcon",shape,string.format(
                "Rectangle %d,17,3,12 | Fill Color 115,255,190,%d | StrokeWidth 0",x,math.floor(255*opacity)))
        end
    elseif name=="Extra" then
        set("TimerExtraLabel","FontColor",string.format("195,235,255,%d",math.floor(255*opacity)))
    else
        set("TimerEndIcon","Shape",string.format(
            "Line 19,19,27,27 | StrokeWidth 3.5 | Stroke Color 255,190,198,%d",math.floor(255*opacity)))
        set("TimerEndIcon","Shape2",string.format(
            "Line 27,19,19,27 | StrokeWidth 3.5 | Stroke Color 255,190,198,%d",math.floor(255*opacity)))
    end
end
local function render()
    local progress=clamp(displayProgress/100,0,1)
    local zone=progress<0.70 and 0 or (progress<0.85 and 1 or 2)
    local base=zone==0 and {25,232,139} or (zone==1 and {255,158,28} or {255,43,57})
    if zone~=colorZone then
        colorZone,colorStep=zone,0
        colorFrom={colorCurrent[1],colorCurrent[2],colorCurrent[3]}
        colorTo=base
    end
    if colorStep<3 then
        colorStep=colorStep+1
        local t=colorStep/3
        local ease=t*t*(3-2*t)
        for channel=1,3 do
            colorCurrent[channel]=colorFrom[channel]+(colorTo[channel]-colorFrom[channel])*ease
        end
    end
    local shimmer=0.87+0.13*math.sin(frame*0.13)
    local rgb=string.format("%d,%d,%d",math.floor(colorCurrent[1]*shimmer),
        math.floor(colorCurrent[2]*shimmer),math.floor(colorCurrent[3]*shimmer))
    local finished=state.status=="finished"
    local breath=(math.sin(frame*0.15)+1)/2
    set("TimerProgress","LineColor",rgb..",255")
    set("TimerOuterGlow","Shape",string.format(
        "Ellipse 130,120,105,105 | Fill Color 0,0,0,0 | StrokeWidth %.1f | Stroke Color %s,%d",
        8+breath*6,rgb,finished and math.floor(80+breath*130) or math.floor(30+breath*50)))
    set("TimerFace","Shape",string.format(
        "Ellipse 130,120,90,90 | Fill Color 5,16,21,215 | StrokeWidth 1 | Stroke Color %s,%d",
        rgb,math.floor(100+breath*90)))
    local envelope=0.72+0.28*math.sin(frame*0.045+0.4)
    for i=1,160 do
        local angle=i*math.pi/80
        local spin=angle-frame*0.055
        local wave=(math.sin(3*spin)+math.sin(7*spin+0.4)+2)/4
        local swell=(math.sin(2*spin+frame*0.01)+1)/2
        local length=4+(7+12*envelope+5*swell)*wave
        local x1,y1=130+math.cos(angle)*97,130+math.sin(angle)*97
        local x2,y2=130+math.cos(angle)*(97+length),130+math.sin(angle)*(97+length)
        set("TimerWaves",i==1 and "Shape" or "Shape"..i,string.format(
            "Line %.1f,%.1f,%.1f,%.1f | StrokeWidth 3 | Stroke Color %s,%d",
            x1,y1,x2,y2,rgb,math.floor(38+wave*165)))
    end
    updateDigits(rgb,zone)
    local idle=state.status=="idle"
    local showDigits=not finished and not idle
    for _,name in ipairs({"Hours","Minutes","Seconds"}) do
        set("Timer"..name,"Hidden",showDigits and "0" or "1")
        set("Timer"..name.."GhostBefore","Hidden",showDigits and "0" or "1")
        set("Timer"..name.."GhostAfter","Hidden",showDigits and "0" or "1")
        set("Timer"..name.."Unit","Hidden",showDigits and "0" or "1")
    end
    set("TimerGameOver","Hidden",finished and "0" or "1")
    set("TimerGameOverLine2","Hidden",finished and "0" or "1")
    set("TimerIdlePrompt","Hidden",idle and "0" or "1")
    set("TimerIdlePromptLine2","Hidden",idle and "0" or "1")
    if finished or idle then
        local phase=(frame%10)/10
        local half=phase<0.5 and phase*2 or (1-phase)*2
        local zoom=half*half*(3-2*half)+0.07*math.sin(math.pi*half)*math.sin(2*math.pi*half)
        local size=16+6*zoom
        local color=finished and string.format("255,45,65,%d",math.floor(160+95*zoom))
            or string.format("65,225,170,%d",math.floor(130+105*zoom))
        local top=finished and "TimerGameOver" or "TimerIdlePrompt"
        local bottom=finished and "TimerGameOverLine2" or "TimerIdlePromptLine2"
        set(top,"FontSize",string.format("%.1f",size))
        set(bottom,"FontSize",string.format("%.1f",size))
        set(top,"Y",string.format("%.1f",418-2*zoom))
        set(bottom,"Y",string.format("%.1f",442+2*zoom))
        set(top,"FontColor",color)
        set(bottom,"FontColor",color)
    end
    set("TimerPlayIcon","Hidden",state.status=="running" and "1" or "0")
    set("TimerPauseIcon","Hidden",state.status=="running" and "0" or "1")
    set("TimerExtraLabel","Text",state.extraCount==0 and "+" or
        (state.extraCount==3 and "MAX" or "x"..(state.extraCount+1)))
    if playActionEnabled~=state.configured then
        playActionEnabled=state.configured
        local action=state.configured and '[!CommandMeasure SessionTimer "StartPause()"]' or ''
        local cursor=state.configured and '1' or '0'
        for _,meter in ipairs({"TimerPlayButton","TimerPlayIcon","TimerPauseIcon","HitArea_TimerPlay"}) do
            set(meter,"LeftMouseUpAction",action)
            set(meter,"MouseActionCursor",cursor)
        end
        SKIN:Bang("!UpdateMeter","HitArea_TimerPlay")
    end
    renderButton("Play","30,245,145")
    renderButton("Extra","65,180,255")
    renderButton("End","240,95,115")
    if frame<noticeUntil then
        local prefix=language=="es-MX" and SKIN:GetVariable("TimerExtraPrefix","!") or ""
        set("TimerExtraNotice","Text",string.format("%s%d min Extra!",prefix,state.extraCount*state.extraStep))
        set("TimerExtraNotice","FontColor",string.format("115,220,255,%d",math.min(255,(noticeUntil-frame)*18)))
    else
        set("TimerExtraNotice","Text","")
    end
    SKIN:Bang("!UpdateMeterGroup","Module_timer")
    SKIN:Bang("!Redraw")
end
function Update()
    frame=frame+1
    if frame==1 and language~="es-MX" then
        set("TimerIdlePrompt","Text","START")
    end
    if frame%5==0 then
        local latest=readState()
        if latest and (latest.baseDuration~=state.baseDuration or latest.extraStep~=state.extraStep or
            latest.extraCount~=state.extraCount or latest.duration~=state.duration or
            latest.status~=state.status or latest.deadline~=state.deadline or
            latest.configured~=state.configured) then
            state=latest
            resetDigits()
        end
    end
    if state.status=="running" then
        state.remaining=clamp(state.deadline-os.time(),0,state.duration)
        if state.remaining==0 then
            state.status,state.deadline="finished",0
            saveState()
        end
    end
    local targetProgress=clamp((state.duration-state.remaining)*100/state.duration,0,100)
    if state.status=="idle" then
        displayProgress,progressVelocity=0,0
    else
        local previous=displayProgress
        progressVelocity=(progressVelocity+(targetProgress-displayProgress)*0.12)*0.65
        displayProgress=clamp(displayProgress+progressVelocity,0,100)
        if state.status=="running" and targetProgress>=previous then
            displayProgress=math.min(targetProgress,math.max(previous,displayProgress))
        end
        if math.abs(targetProgress-displayProgress)<0.0001 and math.abs(progressVelocity)<0.0001 then
            displayProgress,progressVelocity=targetProgress,0
        end
    end
    if enabled then render() end
    return displayProgress
end
