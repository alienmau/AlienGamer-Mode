local canvasWidth, canvasHeight = 1711, 1023
local maximumParticles = 48
local particles = {}
local enabled, particleCount, globalSpeed = true, 26, 0.65
local currentSizeScale, targetSizeScale = 1.0, 1.0
local lastEnabled, lastCount = nil, nil
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
    particleCount = clamp(tonumber(SKIN:GetVariable('BackgroundParticleCount', tostring(particleCount))) or particleCount, 8, maximumParticles)
    globalSpeed = clamp(tonumber(SKIN:GetVariable('BackgroundParticleSpeed', tostring(globalSpeed))) or globalSpeed, 0.2, 1.5)
    targetSizeScale = clamp(tonumber(SKIN:GetVariable('BackgroundParticleSize', tostring(targetSizeScale))) or targetSizeScale, 0.7, 1.6)
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
    particleCount = clamp(tonumber(SELF:GetOption('ParticleCount', '26')) or 26, 8, maximumParticles)
    globalSpeed = clamp(tonumber(SELF:GetOption('ParticleSpeed', '0.65')) or 0.65, 0.2, 1.5)
    targetSizeScale = clamp(tonumber(SELF:GetOption('ParticleSize', '1.00')) or 1.0, 0.7, 1.6)
    currentSizeScale = targetSizeScale
    initializeParticles()
    readRuntimeSettings()
    syncVisibility()
end

function Update()
    readRuntimeSettings()
    syncVisibility()
    if not enabled then return 0 end

    elapsed = elapsed + 0.1
    local sizeChanging = math.abs(targetSizeScale - currentSizeScale) > 0.004
    if sizeChanging then currentSizeScale = currentSizeScale + (targetSizeScale - currentSizeScale) * 0.18
    else currentSizeScale = targetSizeScale end
    for index = 1, particleCount do
        local particle = particles[index]
        particle.progress = particle.progress + particle.speed * globalSpeed * 0.1
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
        local alpha = math.floor(clamp(particle.maxAlpha * fadeIn * fadeOut * pulse, 0, 245) + 0.5)
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
