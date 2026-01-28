MathUtils = {}
local PI = math.pi
local DEGRAD = PI / 180.0

function MathUtils.NormalizeVector(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if len == 0 then return vector3(0, 0, 0) end
    return vector3(v.x / len, v.y / len, v.z / len)
end

function MathUtils.RotationToDirection(rotation)
    local adjustedRotation = vector3(DEGRAD * rotation.x, DEGRAD * rotation.y, DEGRAD * rotation.z)
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), 
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), 
        math.sin(adjustedRotation.x)
    )
    return direction
end

function MathUtils.CalculateAngle(v1, v2)
    local dot = (v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z)
    local mag1 = math.sqrt(v1.x^2 + v1.y^2 + v1.z^2)
    local mag2 = math.sqrt(v2.x^2 + v2.y^2 + v2.z^2)
    if mag1 == 0 or mag2 == 0 then return 0.0 end
    local cosTheta = dot / (mag1 * mag2)
    if cosTheta > 1.0 then cosTheta = 1.0 elseif cosTheta < -1.0 then cosTheta = -1.0 end
    return math.deg(math.acos(cosTheta))
end

function MathUtils.DistanceFromLineToPoint(lineStart, lineDir, point)
    local w = point - lineStart
    local c1 = (w.x * lineDir.x) + (w.y * lineDir.y) + (w.z * lineDir.z)
    if c1 <= 0 then return #(point - lineStart) end 
    local projection = lineStart + (lineDir * c1)
    return #(point - projection)
end

function MathUtils.GetHeadCoords(ped)
    local success, coords = pcall(GetPedBoneCoords, ped, 31086, 0.0, 0.0, 0.0)
    if success and coords.x ~= 0 then return coords end
    return GetEntityCoords(ped)
end

function MathUtils.Average(t)
    local sum = 0
    for _,v in pairs(t) do sum = sum + v end
    return sum / #t
end

function MathUtils.StandardDeviation(t)
    local m = MathUtils.Average(t)
    local vm = 0
    for _,v in pairs(t) do vm = vm + (v - m)^2 end
    return math.sqrt(vm / (#t - 1))
end