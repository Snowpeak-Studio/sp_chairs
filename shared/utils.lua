local up = vector3(0.0, 0.0, 1.0)
local pi = math.pi
--- Calculates the Cross product of two vectors
---@param a vector3
---@param b vector3
---@return vector3
local pi = pi
local function cross(a, b)
    return vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end
--- Gets the direction of a heading
---@param heading number
---@return vector3
local function getDirection(heading)
    local rad = (heading % 360.0) / 180.0 * pi
    return vector3(math.cos(rad), math.sin(rad), 0)
end

local function fromRotation(vector)
    local pitch, yaw = (vector.x % 360.0) / 180.0 * pi, (vector.z % 360.0) / 180.0 * pi

    return vector3(
        math.cos(yaw) * math.cos(pitch),
        math.sin(yaw) * math.cos(pitch),
        math.sin(pitch)
    )
end

--- Converts a vector to a rotation using the specified method
---@param vector vector
---@param method number
---@return vector3
local function toRotation(vector, method)
    if method == 1 then
        -- Assuming vector is normalized
        local yaw = math.atan2(vector.y, vector.x) * 180.0 / pi
        local pitch = math.asin(dot(vector, vec3(0, 0, 0))) * 180.0 / pi
        return vector3(pitch, 0.0, yaw - 90)
    elseif method == 2 then
        local v1 = cross(vector, vector3(0, 0, 1))
        local v2 = cross(vector, v1)

        local r11, r12, r13 = vector.x, v1.x, v2.x
        local r21, r22, r23 = vector.y, v1.y, v2.y
        local r31, r32, r33 = vector.z, v1.z, v2.z

        return vector3(
            math.deg(math.atan2(r32, r33)),
            math.deg(math.atan2(-r31, r32 / r33)) - 90,
            math.deg(math.atan2(r21, r11))
        )
    else
        error("Invalid method specified")
    end
end


--- Converts a rotation to a direction
---@param rotation vector3
---@return vector3
local function rotationToDirection(rotation)
    local adjustedRotation = vector3((pi / 180) * rotation.x, (pi / 180) * rotation.y, (pi / 180) * rotation.z)
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    return direction
end


--- Calculates the dot product of two vectors
---@param a vector3
---@param b vector3
local function dot(a, b)
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
end

--- Calculates the magnitude of a vector
---@param vector vector
---@return vector
local function normalize(vector)
    if type(vector) == "vector3" then
        local norm = math.sqrt(vector.x ^ 2 + vector.y ^ 2 + vector.z ^ 2)
        if norm ~= 0 then
            return vector3(vector.x / norm, vector.y / norm, vector.z / norm)
        end
    end
    return vector
end

--- Returns the magnitude of a vector
---@param a vector3
---@param b vector3
---@param t number
---@return vector3
local function lerp(a, b, t)
    return a + math.min(math.max(t, 0), 1) * (b - a)
end

--- Converts a table to a vector
--- @param tab table
--- @return vector3|vector4|vector2|nil
local function toVec(tab)
    if not tab or type(tab) ~= "table" or not tab.x then
        return tab
    end
    if (tab.w or tab.h or tab.heading or tab.head) then
        return vector4(tab.x, tab.y, tab.z, (tab.w or tab.h or tab.heading or tab.head))
    elseif (tab.z) then
        return vector3(tab.x, tab.y, tab.z)
    else
        return vector2(tab.x, tab.y)
    end
end

return {
    cross = cross,
    getDirection = getDirection,
    fromRotation = fromRotation,
    toRotation = toRotation,
    rotationToDirection = rotationToDirection,
    normalize = normalize,
    lerp = lerp,
    dot = dot,
    toVec = toVec,
}
