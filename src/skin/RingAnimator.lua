local targetMeasure = ""
local smoothing = 0.38
local currentValue = nil

-- Rainmeter requiere Lua en UTF-8 sin BOM.
function Initialize()
    targetMeasure = SELF:GetOption("TargetMeasure", "")
    smoothing = tonumber(SELF:GetOption("Smoothing", "0.38")) or 0.38
    smoothing = math.max(0.05, math.min(1, smoothing))
end

function Update()
    local source = SKIN:GetMeasure(targetMeasure)
    if source == nil then
        return -1
    end

    local rawValue = source:GetValue()
    if rawValue == nil or rawValue ~= rawValue or rawValue < 0 then
        return -1
    end

    -- Se anima el avance relativo del anillo, no el valor numérico real.
    local targetValue = math.max(0, math.min(100, source:GetRelativeValue() * 100))
    if currentValue == nil then
        currentValue = targetValue
    else
        local difference = targetValue - currentValue
        if math.abs(difference) < 0.08 then
            currentValue = targetValue
        else
            currentValue = currentValue + (difference * smoothing)
        end
    end
    return currentValue
end
