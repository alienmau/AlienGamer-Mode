local canvasWidth, canvasHeight = 1711, 1023
local maximumParticles = 48
local particles = {}
local enabled, mode, particleCount, configuredCount, globalSpeed = true, 'manual', 26, 26, 0.65
local currentSizeScale, targetSizeScale = 1.0, 1.0
local currentCount, targetCount = 26, 26
local currentSpeed, targetSpeed = 0.65, 0.65
local currentColor, targetColor = {255, 112, 20}, {255, 112, 20}
local lastEnabled, lastCount, lastTint = nil, nil, ''
local frameTimes, sensorTick, invalidFrameSamples = {}, 0, 0
local thermalPressure = 0
local gpuProtectionThreshold = 88
local thermalMinimumParticles, thermalMaximumParticles = 8, 32
local thermalBaseSpeed, thermalSizeScale = 0.75, 1.0
local elapsed = 0

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function smoothstep(value)
    value = clamp(value, 0, 1)
    return value * value * (3 - 2 * value)
end

local function randomRange(minimum, maximum)
    return minimum + math.random() * (maximum - minimum)
end

local function lerp(a, b, amount)
    return a + (b - a) * amount
end

local function measureValue(name)
    local measure = SKIN:GetMeasure(name)
    if not measure then return nil end
    local value = tonumber(measure:GetValue())
    if not value or value < 0 or value ~= value then return nil end
    return value
end

local function parseColor(value)
    local red, green, blue = string.match(value or '', '^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$')
    if not red then return {255, 112, 20} end
    return {clamp(tonumber(red), 0, 255), clamp(tonumber(green), 0, 255), clamp(tonumber(blue), 0, 255)}
end

local function thermalLevel(value, coolLimit, hotLimit)
    if not value then return 0, 0 end
    if value >= hotLimit then return 2, clamp((value - hotLimit) / 15 + 0.78, 0, 1) end
    if value >= coolLimit then return 1, clamp(0.35 + (value - coolLimit) / (hotLimit - coolLimit) * 0.43, 0, 0.78) end
    return 0, clamp((value - 30) / math.max(coolLimit - 30, 1) * 0.35, 0, 0.35)
end

local function updateThermalTargets()
    local gpuTemperature = measureValue('GPU_TEMP')
    local cpuTemperature = measureValue('CPU_TEMP')
    local coreMaximum = measureValue('CORE_MAX')
    if coreMaximum and (not cpuTemperature or coreMaximum > cpuTemperature) then cpuTemperature = coreMaximum end

    local gpuLevel, gpuPressure = thermalLevel(gpuTemperature, 55, 75)
    local cpuLevel, cpuPressure = thermalLevel(cpuTemperature, 60, 85)
    local level = math.max(gpuLevel, cpuLevel)
    thermalPressure = math.max(gpuPressure, cpuPressure)
    if (measureValue('CPU_THERMAL_ALERT') or 0) >= 1 or (measureValue('GPU_THERMAL_ALERT') or 0) >= 1 then
        level, thermalPressure = 2, 1
    end
    if not gpuTemperature and not cpuTemperature then targetColor = parseColor(SKIN:GetVariable('BackgroundParticleColor', '255,112,20'))
    elseif level == 2 then targetColor = {255, 35, 45}
    elseif level == 1 then targetColor = {255, 170, 35}
    else targetColor = {55, 170, 255} end

    local gpuUse = measureValue('GPU_USE')
    local cpuUse = measureValue('CPU_USE')
    local activity = clamp(math.max(gpuUse or 0, cpuUse or 0) / 100, 0, 1)
    local frameTime = measureValue('FRAME_TIME')
    local fps = measureValue('FPS_GAME')
    if frameTime and frameTime > 0 and frameTime < 250 then
        invalidFrameSamples = 0
        table.insert(frameTimes, frameTime)
        if #frameTimes > 8 then table.remove(frameTimes, 1) end
    else
        invalidFrameSamples = invalidFrameSamples + 1
        if invalidFrameSamples >= 3 then frameTimes = {} end
    end

    local smoothness = activity * 0.45
    local framePressure = 0
    if #frameTimes >= 2 then
        local sum = 0
        for _, value in ipairs(frameTimes) do sum = sum + value end
        local average = sum / #frameTimes
        local variance = 0
        for _, value in ipairs(frameTimes) do variance = variance + (value - average) ^ 2 end
        local deviation = math.sqrt(variance / #frameTimes)
        local pace = clamp((50 - average) / 41.7, 0, 1)
        local stabilityPenalty = clamp((deviation / math.max(average, 1)) * 1.8, 0, 0.65)
        smoothness = pace * (1 - stabilityPenalty)
        framePressure = clamp((average - 20) / 30 + stabilityPenalty * 0.5, 0, 1)
    elseif fps and fps > 0 then
        smoothness = clamp((fps - 20) / 100, 0, 1)
    end

    local density = clamp(smoothness * 0.70 + activity * 0.30, 0, 1)
    local requestedCount = thermalMinimumParticles + (thermalMaximumParticles - thermalMinimumParticles) * density
    -- Cuando el juego ya está saturando la GPU, el fondo debe ceder recursos en
    -- vez de aumentar partículas por la lectura de actividad. La reducción es
    -- progresiva y también considera frame time degradado para evitar saltos.
    local gpuPressure = clamp(((gpuUse or 0) - gpuProtectionThreshold) / math.max(100 - gpuProtectionThreshold, 1), 0, 1)
    local protection = math.max(gpuPressure, framePressure * 0.55)
    targetCount = thermalMinimumParticles + (requestedCount - thermalMinimumParticles) * (1 - protection * 0.82)
    targetSpeed = clamp(thermalBaseSpeed * (0.45 + activity * 0.55) * (1 - protection * 0.55), 0.2, thermalBaseSpeed)
    targetSizeScale = thermalSizeScale
end

local function resetParticle(particle, initial)
    particle.depth = randomRange(0.38, 1.0)
    -- El tamaño máximo de la calibración anterior se convierte en la nueva
    -- referencia base (100%) para todo el control global.
    particle.size = randomRange(20, 60) * (0.62 + particle.depth * 0.55)
    particle.baseX = randomRange(-35, canvasWidth + 35)
    particle.startY = canvasHeight + randomRange(12, 190)
    -- El 70% se concentra y desvanece en la mitad inferior. El 30% restante
    -- completa el ascenso y rebasa ligeramente el borde superior.
    particle.reachesTop = math.random() < 0.30
    particle.endY = particle.reachesTop and randomRange(-95, -20) or randomRange(canvasHeight * 0.25, canvasHeight * 0.72)
    particle.progress = initial and randomRange(0, 1) or 0
    particle.speed = randomRange(0.026, 0.072) * (0.62 + particle.depth * 0.62)
    particle.driftA = randomRange(18, 82) * (0.55 + particle.depth * 0.55)
    particle.driftB = randomRange(7, 34)
    particle.driftRateA = randomRange(0.38, 0.92)
    particle.driftRateB = randomRange(0.90, 1.85)
    particle.phaseA = randomRange(0, math.pi * 2)
    particle.phaseB = randomRange(0, math.pi * 2)
    particle.pulseRate = randomRange(1.0, 2.8)
    particle.pulsePhase = randomRange(0, math.pi * 2)
    particle.fadeStart = particle.reachesTop and randomRange(0.72, 0.90) or randomRange(0.52, 0.78)
    particle.maxAlpha = math.floor(randomRange(105, 225) * (0.62 + particle.depth * 0.42))
end

local function initializeParticles()
    math.randomseed(os.time() + math.floor(os.clock() * 100000))
    for index = 1, maximumParticles do
        particles[index] = {}
        resetParticle(particles[index], true)
        local size = particles[index].size * currentSizeScale
        SKIN:Bang('!SetOption', 'Particle' .. index, 'W', string.format('%.2f', size))
        SKIN:Bang('!SetOption', 'Particle' .. index, 'H', string.format('%.2f', size))
    end
end

local function readRuntimeSettings()
    enabled = tonumber(SKIN:GetVariable('BackgroundEffectEnabled', enabled and '1' or '0')) == 1
    mode = string.lower(SKIN:GetVariable('BackgroundEffectMode', mode) or mode)
    if mode ~= 'thermal' then mode = 'manual' end
    configuredCount = clamp(tonumber(SKIN:GetVariable('BackgroundParticleCount', tostring(configuredCount))) or configuredCount, 8, maximumParticles)
    globalSpeed = clamp(tonumber(SKIN:GetVariable('BackgroundParticleSpeed', tostring(globalSpeed))) or globalSpeed, 0.2, 1.5)
    targetSizeScale = clamp(tonumber(SKIN:GetVariable('BackgroundParticleSize', tostring(targetSizeScale))) or targetSizeScale, 0.7, 1.6)
    if mode == 'manual' then
        targetCount, targetSpeed = configuredCount, globalSpeed
        targetColor = parseColor(SKIN:GetVariable('BackgroundParticleColor', '255,112,20'))
        thermalPressure = 0
    end
end

local function syncVisibility()
    if enabled == lastEnabled and particleCount == lastCount then return end
    for index = 1, maximumParticles do
        local visible = enabled and index <= particleCount
        SKIN:Bang(visible and '!ShowMeter' or '!HideMeter', 'Particle' .. index)
        if visible then
            local size = particles[index].size * currentSizeScale
            SKIN:Bang('!SetOption', 'Particle' .. index, 'W', string.format('%.2f', size))
            SKIN:Bang('!SetOption', 'Particle' .. index, 'H', string.format('%.2f', size))
        end
    end
    lastEnabled, lastCount = enabled, particleCount
end

function Initialize()
    enabled = tonumber(SELF:GetOption('Enabled', '1')) == 1
    mode = string.lower(SELF:GetOption('Mode', 'manual'))
    if mode ~= 'thermal' then mode = 'manual' end
    configuredCount = clamp(tonumber(SELF:GetOption('ParticleCount', '26')) or 26, 8, maximumParticles)
    particleCount, currentCount, targetCount = configuredCount, configuredCount, configuredCount
    globalSpeed = clamp(tonumber(SELF:GetOption('ParticleSpeed', '0.65')) or 0.65, 0.2, 1.5)
    currentSpeed, targetSpeed = globalSpeed, globalSpeed
    targetSizeScale = clamp(tonumber(SELF:GetOption('ParticleSize', '1.00')) or 1.0, 0.7, 1.6)
    gpuProtectionThreshold = clamp(tonumber(SELF:GetOption('GpuProtectionThreshold', '88')) or 88, 70, 98)
    thermalMinimumParticles = clamp(tonumber(SELF:GetOption('ThermalMinimumParticles', '8')) or 8, 4, 16)
    thermalMaximumParticles = clamp(tonumber(SELF:GetOption('ThermalMaximumParticles', '32')) or 32, thermalMinimumParticles, 40)
    thermalBaseSpeed = clamp(tonumber(SELF:GetOption('ThermalBaseSpeed', '0.75')) or 0.75, 0.2, 1.2)
    thermalSizeScale = clamp(tonumber(SELF:GetOption('ThermalSizeScale', '1.00')) or 1.0, 0.7, 1.3)
    currentSizeScale = targetSizeScale
    currentColor = parseColor(SKIN:GetVariable('BackgroundParticleColor', '255,112,20'))
    targetColor = {currentColor[1], currentColor[2], currentColor[3]}
    initializeParticles()
    readRuntimeSettings()
    syncVisibility()
end

function Update()
    readRuntimeSettings()
    sensorTick = sensorTick + 1
    if mode == 'thermal' and (sensorTick == 1 or sensorTick >= 10) then
        sensorTick = 0
        updateThermalTargets()
    end
    local countAmount = targetCount >= currentCount and 0.08 or 0.035
    local speedAmount = targetSpeed >= currentSpeed and 0.07 or 0.035
    currentCount = lerp(currentCount, targetCount, countAmount)
    currentSpeed = lerp(currentSpeed, targetSpeed, speedAmount)
    particleCount = clamp(math.floor(currentCount + 0.5), 8, maximumParticles)
    for channel = 1, 3 do currentColor[channel] = lerp(currentColor[channel], targetColor[channel], 0.055) end
    local tint = string.format('%d,%d,%d', math.floor(currentColor[1] + 0.5), math.floor(currentColor[2] + 0.5), math.floor(currentColor[3] + 0.5))
    if tint ~= lastTint then
        SKIN:Bang('!SetOptionGroup', 'AmbientParticles', 'ImageTint', tint)
        lastTint = tint
    end
    syncVisibility()
    if not enabled then return 0 end

    elapsed = elapsed + 0.1
    local sizeChanging = math.abs(targetSizeScale - currentSizeScale) > 0.004
    if sizeChanging then currentSizeScale = currentSizeScale + (targetSizeScale - currentSizeScale) * 0.18
    else currentSizeScale = targetSizeScale end
    for index = 1, particleCount do
        local particle = particles[index]
        particle.progress = particle.progress + particle.speed * currentSpeed * 0.1
        if particle.progress >= 1 then
            resetParticle(particle, false)
            local resetSize = particle.size * currentSizeScale
            SKIN:Bang('!SetOption', 'Particle' .. index, 'W', string.format('%.2f', resetSize))
            SKIN:Bang('!SetOption', 'Particle' .. index, 'H', string.format('%.2f', resetSize))
        end

        local rise = smoothstep(particle.progress)
        local y = particle.startY + (particle.endY - particle.startY) * rise
        local x = particle.baseX
            + math.sin(elapsed * particle.driftRateA + particle.phaseA) * particle.driftA
            + math.sin(elapsed * particle.driftRateB + particle.phaseB) * particle.driftB

        local fadeIn = smoothstep(particle.progress / 0.13)
        local fadeOut = 1 - smoothstep((particle.progress - particle.fadeStart) / (1 - particle.fadeStart))
        local pulse = 0.62 + 0.38 * ((math.sin(elapsed * particle.pulseRate + particle.pulsePhase) + 1) * 0.5)
        local thermalGlow = mode == 'thermal' and (0.82 + thermalPressure * 0.25) or 1
        local alpha = math.floor(clamp(particle.maxAlpha * fadeIn * fadeOut * pulse * thermalGlow, 0, 245) + 0.5)
        local size = particle.size * currentSizeScale
        local meter = 'Particle' .. index

        if sizeChanging then
            SKIN:Bang('!SetOption', meter, 'W', string.format('%.2f', size))
            SKIN:Bang('!SetOption', meter, 'H', string.format('%.2f', size))
        end

        SKIN:Bang('!SetOption', meter, 'X', string.format('%.2f', x - size * 0.5))
        SKIN:Bang('!SetOption', meter, 'Y', string.format('%.2f', y - size * 0.5))
        SKIN:Bang('!SetOption', meter, 'ImageAlpha', alpha)
    end
    -- La skin actualizará sus medidores y dibujará una sola vez al terminar el
    -- ciclo. Forzarlo aquí duplicaría el render de pantalla completa.
    return 0
end
