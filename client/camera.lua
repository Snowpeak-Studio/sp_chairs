--- Original Credit: https://github.com/kerminal/FiveM-Framework/blob/main/resources/%5Bmisc%5D/camera/cl_camera.lua
--- Shake types:
--- - "DEATH_FAIL_IN_EFFECT_SHAKE"
--- - "DRUNK_SHAKE"
--- - "FAMILY5_DRUG_TRIP_SHAKE"
--- - "HAND_SHAKE"
--- - "JOLT_SHAKE"
--- - "LARGE_EXPLOSION_SHAKE"
--- - "MEDIUM_EXPLOSION_SHAKE"
--- - "SMALL_EXPLOSION_SHAKE"
--- - "ROAD_VIBRATION_SHAKE"
--- - "SKY_DIVING_SHAKE"
--- - "VIBRATE_SHAKE"

---@class CameraData
---@field id? integer
---@field handle? integer
---@field type? string
---@field coords? vector3
---@field rotation? vector3
---@field fov? number
---@field lookAt? vector3|number
---@field shake? { type?: string, amount?: number }
---@field isActive? boolean

---@class Camera: CameraData
Camera = {}
Camera.__index = Camera

---@class CamerasTable
---@field lastId integer
---@field objects table<integer, Camera>
Cameras = {
    lastId = 0,
    objects = {},
}

---Create a new Camera instance.
---@param data? CameraData
---@return Camera
function Camera:Create(data)
    if not data then data = {} end

    data.handle = CreateCam(data.type or "DEFAULT_SCRIPTED_CAMERA", false)
    data.id = Cameras.lastId + 1

    setmetatable(data, self)

    Cameras.lastId = data.id
    Cameras.objects[data.id] = data

    return data
end

---Activate the camera, set active and render.
function Camera:Activate()
    if not DoesCamExist(self.handle) then return end

    SetCamActive(self.handle, true)
    self.isActive = true

    RenderScriptCams(true, false, 0, 1, 0)

    if self.shake then
        ShakeCam(self.handle, self.shake.type or "HAND_SHAKE", self.shake.amount or 1.0)
    end
end

---Deactivate the camera and stop rendering.
function Camera:Deactivate()
    if not DoesCamExist(self.handle) then return end

    if IsCamRendering(self.handle) then
        RenderScriptCams(false, false, 0, 1, 0)
    end

    if IsCamActive(self.handle) then
        SetCamActive(self.handle, false)
    end

    self.isActive = false
end

---Destroy the camera and remove it from cache.
function Camera:Destroy()
    if not DoesCamExist(self.handle) then return end

    if self.isActive then
        self:Deactivate()
    end

    DestroyCam(self.handle)
    Cameras.objects[self.id] = nil
end

---Update the camera properties each frame.
function Camera:Update()
    if self.coords then
        SetCamCoord(self.handle, self.coords)
    end

    if self.rotation then
        SetCamRot(self.handle, self.rotation)
    end

    if self.fov then
        SetCamFov(self.handle, self.fov)
    end

    if self.lookAt then
        local _type = type(self.lookAt)
        if _type == "vector3" then
            PointCamAtCoord(self.handle, self.lookAt)
        elseif _type == "number" then
            PointCamAtEntity(self.handle, self.lookAt)
        end
    end
end

--[[ Threads ]]
Citizen.CreateThread(function()
    while true do
        for id, camera in pairs(Cameras.objects) do
            if camera.isActive then
                camera:Update()
            end
        end
        Citizen.Wait(0)
    end
end)
