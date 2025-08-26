---@class ChairsAnim
---@field dict string
---@field name string
---@field flag? number

---@class PoseCamera
---@field offset vector3
---@field target vector3
---@field fov? number

---@class PoseEntry
---@field offset vector3
---@field rotation vector3
---@field anim? ChairsAnim
---@field camera? PoseCamera

---@class ModelsMap
---@field [integer]: table<string, PoseEntry>

---@class BasesMap
---@field [string]: { anim?: ChairsAnim, text?: string }

---@type table
local Config    = require 'shared.config'
---@type BasesMap
local Bases     = require 'shared.bases'
---@type ModelsMap
local Models    = require 'shared.models'
local Utils     = require 'shared.utils'
local ox_target = exports.ox_target
require 'client.camera'
-- ========= helpers =========

---Play an animation, auto-request/unload dict.
---@param ped number
---@param anim ChairsAnim|nil
local function playAnim(ped, anim)
    anim = anim or Config.Default
    if not anim or not anim.dict or not anim.name then return end
    if lib.requestAnimDict(anim.dict, 10000) then
        lib.playAnim(ped, anim.dict, anim.name, 8.0, 8.0, -1, anim.flag or 0, 0.0, false, 0, false)
        RemoveAnimDict(anim.dict)
    end
end

---Attach a ped to an entity using pose offset/rotation.
---@param ped number
---@param entity number
---@param offset vector3
---@param rotation vector3
local function attachPedToEntity(ped, entity, offset, rotation)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, GetEntityCoords(entity)) -- ensure same interior/room
    AttachEntityToEntity(
        ped, entity, 0,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, false, true, false, 2, true
    )
end

---Create and activate a simple “look-at” camera for a pose.
---@param entity number
---@param camera PoseCamera|nil
---@return table|nil cam
local function createPoseCamera(entity, camera)
    if not camera then return nil end
    local origin = GetOffsetFromEntityInWorldCoords(entity, camera.offset.x, camera.offset.y, camera.offset.z)
    local target = GetOffsetFromEntityInWorldCoords(entity, camera.target.x, camera.target.y, camera.target.z)

    ---@type table
    local cam = Camera:Create({
        coords = origin,
        rotation = Utils.toRotation(Utils.normalize(target - origin), 1),
        fov = camera.fov or 55.0
    })
    cam:Activate()
    return cam
end

---Execute a pose on an entity (attach, anim, optional camera).
---@param entity number
---@param baseName string
local function doPose(entity, baseName)
    local ped      = cache.ped
    local model    = GetEntityModel(entity)
    ---@type table<string, PoseEntry>
    local perModel = Models[model] or {}
    ---@type PoseEntry|nil
    local entry    = perModel[baseName]
    ---@type { anim?: ChairsAnim, text?: string }|nil
    local base     = Bases[baseName]

    if not entry or not base then return end

    local offset   = entry.offset or vector3(0.0, 0.0, 0.0)
    local rotation = entry.rotation or vector3(0.0, 0.0, 0.0)
    local anim     = entry.anim or base.anim or Config.Default

    -- attach + anim
    attachPedToEntity(ped, entity, offset, rotation)
    playAnim(ped, anim)

    -- optional camera
    local cam = createPoseCamera(entity, entry.camera)
    lib.showTextUI('[E] Stand up', {
        type = 'inform',
        icon = 'fa-solid fa-chair',
        position = 'right-center'
    })
    -- basic stand-up on E
    CreateThread(function()
        while DoesEntityExist(entity) and IsEntityAttachedToEntity(ped, entity) do
            if IsControlJustReleased(0, 38) then -- E
                DetachEntity(ped, true, true)
                FreezeEntityPosition(ped, false)
                ClearPedTasksImmediately(ped)
                lib.hideTextUI()
                if cam then cam:Destroy() end
                break
            end
            Wait(0)
        end
        if cam then cam:Destroy() end
    end)
end

---Check if an entity has a pose key.
---@param entity number
---@param pose string
---@return boolean
local function hasPose(entity, pose)
    ---@type table<string, PoseEntry>|nil
    local t = Models[GetEntityModel(entity)]
    return t ~= nil and t[pose] ~= nil
end

-- ========= events =========

---Client-side trigger to perform a pose.
---@param entity number
---@param pose string
RegisterNetEvent('sp_chairs:doPose', function(entity, pose)
    if not DoesEntityExist(entity) then return end
    doPose(entity, pose)
end)

---Force “medical” on the nearest supported model within 2.0m.
RegisterNetEvent('sp_chairs:forceMedical', function()
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local closestEnt, closestModel, bestDist = 0, 0, 2.0
    for model, poses in pairs(Models) do
        if poses.medical then
            local ent = GetClosestObjectOfType(pos.x, pos.y, pos.z, 10.0, model, false, false, false)
            if ent ~= 0 then
                local dist = #(GetEntityCoords(ent) - pos)
                if dist <= bestDist and HasEntityClearLosToEntity(ped, ent, 17) then
                    closestEnt, closestModel, bestDist = ent, model, dist
                end
            end
        end
    end
    if closestEnt ~= 0 then doPose(closestEnt, 'medical') end
end)

-- ========= targets =========

---Register ox_target model options for all supported models/poses.
local function registerTargets()
    -- gather all model ids
    ---@type integer[]
    local models = {}
    for model, _ in pairs(Models) do models[#models + 1] = model end

    ox_target:addModel(models, {
        {
            name = 'sp_chairs:medical',
            icon = 'fa-solid fa-bed',
            label = 'Lay (Medical)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'medical') or false end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'medical') end
        },
        {
            name = 'sp_chairs:chair',
            icon = 'fa-solid fa-chair',
            label = 'Sit (Chair)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'chair') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'chair') end
        },
        {
            name = 'sp_chairs:chair2',
            icon = 'fa-solid fa-chair',
            label = 'Sit (Chair 2)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'chair2') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'chair2') end
        },
        {
            name = 'sp_chairs:chair3',
            icon = 'fa-solid fa-chair',
            label = 'Sit (Chair 3)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'chair3') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'chair3') end
        },
        {
            name = 'sp_chairs:chair4',
            icon = 'fa-solid fa-chair',
            label = 'Sit (Chair 4)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'chair4') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'chair4') end
        },
        {
            name = 'sp_chairs:stool',
            icon = 'fa-solid fa-circle-dot',
            label = 'Sit (Stool)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'stool') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'stool') end
        },
        {
            name = 'sp_chairs:slots',
            icon = 'fa-solid fa-slot-machine',
            label = 'Use Slots',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'slots') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'slots') end
        },
        {
            name = 'sp_chairs:sunbed',
            icon = 'fa-solid fa-bed',
            label = 'Lay (Sunbed)',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity) return hasPose(entity, 'sunbed') end,
            ---@param data {entity:number}
            onSelect = function(data) TriggerEvent('sp_chairs:doPose', data.entity, 'sunbed') end
        },
        -- Put person on medical (config-gated)
        {
            name = 'sp_chairs:put_person_medical',
            icon = 'fa-solid fa-user-plus',
            label = 'Put Person On Bed',
            distance = Config.Target.distance,
            ---@param entity number
            canInteract = function(entity)
                if not Config.AllowPutOnMedicalBeds then return false end
                if not hasPose(entity, 'medical') then return false end
                local myPos = GetEntityCoords(cache.ped)
                ---@type number|nil, number|nil
                local pid, ped = lib.getClosestPlayer(myPos, 2.0, false)
                return pid and DoesEntityExist(ped)
            end,
            onSelect = function()
                if not Config.AllowPutOnMedicalBeds then return end
                local myPos = GetEntityCoords(cache.ped)
                ---@type number|nil
                local pid = lib.getClosestPlayer(myPos, 2.0, false)
                if pid then
                    TriggerServerEvent('sp_chairs:putOnMedical', GetPlayerServerId(pid))
                end
            end
        },
    })
end

---ox_target registration on resource start.
---@param res string
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    registerTargets()
end)
