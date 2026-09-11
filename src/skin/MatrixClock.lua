local digits = {
    [0] = {"11111", "10001", "10001", "10001", "10001", "10001", "11111"},
    [1] = {"00100", "01100", "00100", "00100", "00100", "00100", "01110"},
    [2] = {"11111", "00001", "00001", "11111", "10000", "10000", "11111"},
    [3] = {"11111", "00001", "00001", "11111", "00001", "00001", "11111"},
    [4] = {"10001", "10001", "10001", "11111", "00001", "00001", "00001"},
    [5] = {"11111", "10000", "10000", "11111", "00001", "00001", "11111"},
    [6] = {"11111", "10000", "10000", "11111", "10001", "10001", "11111"},
    [7] = {"11111", "00001", "00010", "00100", "01000", "01000", "01000"},
    [8] = {"11111", "10001", "10001", "11111", "10001", "10001", "11111"},
    [9] = {"11111", "10001", "10001", "11111", "00001", "00001", "11111"}
}

local lastClock = ""
local recordProgress = 0
local recordHoverProgress = 0
local offHoverProgress = 0
local pulseTick = 0
local alertWasHigh = {}

local alertRings = {
    {meter = "Ring_GPU_TEMP", measure = "GPU_TEMP", warning = 55, critical = 75, low = "55,170,255,255", middle = "255,170,35,255"},
    {meter = "Ring_GPU_USE", measure = "GPU_USE", warning = 50, critical = 85, low = "95,70,255,255", middle = "255,170,35,255"},
    {meter = "Ring_CPU_TEMP", measure = "CPU_TEMP", warning = 60, critical = 85, low = "55,170,255,255", middle = "255,170,35,255"},
    {meter = "Ring_CPU_USE", measure = "CPU_USE", warning = 50, critical = 85, low = "95,70,255,255", middle = "255,170,35,255"},
    {meter = "Ring_CORE_MAX", measure = "CORE_MAX", warning = 60, critical = 85, low = "55,170,255,255", middle = "255,170,35,255"},
    {meter = "Ring_SSD_TEMP", measure = "SSD_TEMP", warning = 45, critical = 60, low = "255,235,145,255", middle = "255,190,35,255"},
    {meter = "Ring_MeasureRAM", measure = "MeasureRAM", warning = 60, critical = 80, low = "40,220,255,255", middle = "255,170,35,255", relative = true}
}

local function approach(current, target, step)
    if current < target then
        return math.min(current + step, target)
    elseif current > target then
        return math.max(current - step, target)
    end
    return current
end

local function mix(from, to, progress)
    return math.floor(from + ((to - from) * progress) + 0.5)
end

local function mixColor(base, hover, progress, alpha)
    return string.format(
        "%d,%d,%d,%d",
        mix(base[1], hover[1], progress),
        mix(base[2], hover[2], progress),
        mix(base[3], hover[3], progress),
        alpha
    )
end

local function renderDigit(meter, number)
    local index = 0
    for row = 1, 7 do
        for column = 1, 5 do
            index = index + 1
            local active = digits[number][row]:sub(column, column) == "1"
            local color = active and "65,255,175,255" or "20,47,55,210"
            local x = (column - 1) * 9
            local y = (row - 1) * 9
            local option = index == 1 and "Shape" or ("Shape" .. index)
            local square = string.format("Rectangle %d,%d,6,6 | Fill Color %s | StrokeWidth 0", x, y, color)
            SKIN:Bang("!SetOption", meter, option, square)
        end
    end
end

-- Rainmeter requiere este archivo en UTF-8 sin BOM. Un BOM impide cargar Lua.
function Initialize()
    Update()
end

local function updateControls()
    local recording = tonumber(SKIN:GetVariable("RecordingActive", "0")) == 1
    local recordHover = tonumber(SKIN:GetVariable("RecordHover", "0")) == 1
    local offHover = tonumber(SKIN:GetVariable("OffHover", "0")) == 1

    local previousRecord = recordProgress
    local previousRecordHover = recordHoverProgress
    local previousOffHover = offHoverProgress
    recordProgress = approach(recordProgress, recording and 1 or 0, 0.16)
    recordHoverProgress = approach(recordHoverProgress, recordHover and 1 or 0, 0.20)
    offHoverProgress = approach(offHoverProgress, offHover and 1 or 0, 0.20)
    pulseTick = (pulseTick + 1) % 20

    local transitioning = previousRecord ~= recordProgress
        or previousRecordHover ~= recordHoverProgress
        or previousOffHover ~= offHoverProgress
    if not transitioning and not recording then
        return false
    end

    -- El borde derecho permanece fijo. Al grabar, el control crece hacia la izquierda.
    local buttonX = mix(1495, 1435, recordProgress)
    local buttonWidth = mix(145, 205, recordProgress)
    local labelX = mix(1567, 1546, recordProgress)
    local dotX = mix(1509, 1453, recordProgress)

    local inactiveFill = {20, 24, 33}
    local inactiveHover = {31, 38, 51}
    local activeFill = {105, 18, 25}
    local activeHover = {135, 23, 32}
    local fillBase = {
        mix(inactiveFill[1], activeFill[1], recordProgress),
        mix(inactiveFill[2], activeFill[2], recordProgress),
        mix(inactiveFill[3], activeFill[3], recordProgress)
    }
    local fillHover = {
        mix(inactiveHover[1], activeHover[1], recordProgress),
        mix(inactiveHover[2], activeHover[2], recordProgress),
        mix(inactiveHover[3], activeHover[3], recordProgress)
    }
    local borderColor = string.format(
        "%d,%d,%d,255",
        mix(92, 255, recordProgress),
        mix(102, 55, recordProgress),
        mix(120, 65, recordProgress)
    )
    local recordFill = mixColor(fillBase, fillHover, recordHoverProgress, 245)

    SKIN:Bang("!SetOption", "MeterRecordButton", "X", tostring(buttonX))
    SKIN:Bang("!SetOption", "MeterRecordButton", "W", tostring(buttonWidth))
    SKIN:Bang("!SetOption", "MeterRecordButton", "Shape", string.format(
        "Rectangle 0,0,%d,40,10 | Fill Color %s | StrokeWidth 1 | Stroke Color %s",
        buttonWidth, recordFill, borderColor
    ))
    SKIN:Bang("!SetOption", "MeterRecordLabel", "X", tostring(labelX))
    SKIN:Bang("!SetOption", "MeterRecordingDot", "X", tostring(dotX))

    local pulse = 0.5 + (0.5 * math.sin((pulseTick / 20) * 2 * math.pi - (math.pi / 2)))
    local dotAlpha = mix(55, 255, pulse) * recordProgress
    SKIN:Bang("!SetOption", "MeterRecordingDot", "Shape", string.format(
        "Ellipse 0,0,4,4 | Fill Color 255,55,65,%d | StrokeWidth 0",
        math.floor(dotAlpha + 0.5)
    ))

    local offFill = mixColor({35, 18, 48}, {63, 29, 86}, offHoverProgress, 240)
    local offStroke = mixColor({120, 45, 165}, {180, 75, 235}, offHoverProgress, 255)
    SKIN:Bang("!SetOption", "MeterOffButton", "Shape", string.format(
        "Rectangle 0,0,105,40,10 | Fill Color %s | StrokeWidth 1 | Stroke Color %s",
        offFill, offStroke
    ))

    SKIN:Bang("!UpdateMeter", "MeterRecordButton")
    SKIN:Bang("!UpdateMeter", "MeterRecordLabel")
    SKIN:Bang("!UpdateMeter", "MeterRecordingDot")
    SKIN:Bang("!UpdateMeter", "MeterOffButton")
    return true
end

local function updateAlertPulses()
    local changed = false
    local pulse = 0.5 + (0.5 * math.sin((pulseTick / 20) * 2 * math.pi - (math.pi / 2)))
    for _, config in ipairs(alertRings) do
        local source = SKIN:GetMeasure(config.measure)
        if source ~= nil then
            local value = source:GetValue()
            if config.relative and value >= 0 then
                value = source:GetRelativeValue() * 100
            end
            local high = value ~= nil and value == value and value >= config.critical
            if high then
                -- Destello sólido entre dos rojos saturados: nunca aclara hacia
                -- rosa/blanco ni reduce opacidad, por lo que conserva contraste.
                local color = string.format(
                    "%d,0,%d,255",
                    mix(195, 255, pulse),
                    mix(12, 28, pulse)
                )
                SKIN:Bang("!SetOption", config.meter, "LineColor", color)
                SKIN:Bang("!UpdateMeter", config.meter)
                changed = true
            elseif alertWasHigh[config.meter] then
                local baseColor = value >= config.warning and config.middle or config.low
                SKIN:Bang("!SetOption", config.meter, "LineColor", baseColor)
                SKIN:Bang("!UpdateMeter", config.meter)
                changed = true
            end
            alertWasHigh[config.meter] = high
        end
    end
    return changed
end

function Update()
    local now = os.date("*t")
    local currentClock = string.format("%02d%02d%02d", now.hour, now.min, now.sec)
    local redraw = false
    local values = {
        math.floor(now.hour / 10), now.hour % 10,
        math.floor(now.min / 10), now.min % 10,
        math.floor(now.sec / 10), now.sec % 10
    }

    if currentClock ~= lastClock then
        for index = 1, 6 do
            renderDigit("ClockDigit" .. index, values[index])
        end
        lastClock = currentClock
        SKIN:Bang("!UpdateMeterGroup", "MatrixClock")
        redraw = true
    end
    if updateControls() then
        redraw = true
    end
    if updateAlertPulses() then
        redraw = true
    end
    if redraw then
        SKIN:Bang("!Redraw")
    end
    return 0
end
