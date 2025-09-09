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
local Config = require('shared.config')
---@type BasesMap
local Bases  = require('shared.bases')
---@type ModelsMap
local Models = require('shared.models')
local Keys   = require('@sp_core.data.keys')
local Notify = require('@sp_core.bridge.shared').load('ui.notify')
local TextUI = require('@sp_core.bridge.shared').load('ui.textUI')
local Target = require('@sp_core.bridge.shared').load('target')



-- ========= occupancy guard (cached, uses enumerators) =========
local chairCache = { }
local cacheTime = 0

---@param entity number
---@param ped number|nil
---@return boolean
local function isOccupied(entity, ped)
    -- refresh cache every 2s
    if not cacheTime or (GetGameTimer() - cacheTime) > 2000 then
        chairCache = {}
        cacheTime = GetGameTimer()

        for p in sp.enumerateEntities.peds() do
            local attached = IsEntityAttached(p) and GetEntityAttachedTo(p)
            if attached and DoesEntityExist(attached) then
                chairCache[attached] = p
            end
        end
    end

    local attachedPed = chairCache[entity or false]
    return attachedPed ~= nil and (not ped or attachedPed ~= ped)
end

---@param entity number
---@param currentPed number
---@return boolean
local function canUseEntity(entity, currentPed)
    if Config.allowSameEntitySit then return true end
    return not isOccupied(entity, currentPed)
end

-- ========= helpers =========

---Play an animation, auto-request/unload dict.
---@param ped number
---@param anim ChairsAnim|nil
local function playAnim(ped, anim)
    anim = anim or Config.default
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
    local cam = sp.camera.create({
        coords = origin,
        rotation = sp.coords.toRotation(sp.coords.normalize(target - origin), 1),
        fov = camera.fov or 55.0
    })
    cam:activate()
    return cam
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

---Execute a pose on an entity (occupancy check, attach, anim, optional camera).
---@param entity number
---@param baseName string
local function doPose(entity, baseName)
    local ped = cache.ped
    if not canUseEntity(entity, ped) then
        Notify({
            color = 'negative',
            icon = 'fa-solid fa-circle-xmark',
            message = locale('occupied')
        })
        return
    end

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
    local anim     = entry.anim or base.anim or Config.default

    -- attach + anim
    attachPedToEntity(ped, entity, offset, rotation)
    playAnim(ped, anim)

    -- optional camera
    local cam = createPoseCamera(entity, entry.camera)
    TextUI.show('[' .. Config.standUpKey .. '] ' .. locale('getup'), {
        type = 'inform',
        icon = 'fa-solid fa-chair',
        position = 'right-center'
    })
    
    -- basic stand-up on key
    CreateThread(function()
        while DoesEntityExist(entity) and IsEntityAttachedToEntity(ped, entity) do
            if IsControlJustReleased(0, Keys[Config.standUpKey]) or IsDisabledControlJustPressed(0, Keys[Config.standUpKey]) then
                DetachEntity(ped, true, true)
                FreezeEntityPosition(ped, false)
                ClearPedTasksImmediately(ped)
                TextUI.hide()
                if cam then
                    cam:remove()
                    cam = nil
                end
                break
            end
            Wait(0)
        end
        if cam then
            cam:remove()
            cam = nil
        end
    end)
end

---Client-side trigger to perform a pose (respects occupancy).
---@param entity number
---@param pose string
local function checkAndDo(entity, pose)
    if not DoesEntityExist(entity) then return end
    if not canUseEntity(entity, cache.ped) then
        Notify({ type = 'error', description = locale('occupied') })
        return
    end
    doPose(entity, pose)
end


-- ========= events =========


---Force “medical” on the nearest supported model within 2.0m (respects occupancy).
RegisterNetEvent(Shared.event .. 'forceMedical', function()
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local closestEnt, bestDist = 0, 2.0
    for model, poses in pairs(Models) do
        if poses.medical then
            local ent = GetClosestObjectOfType(pos.x, pos.y, pos.z, 10.0, model, false, false, false)
            if ent ~= 0 then
                local dist = #(GetEntityCoords(ent) - pos)
                if dist <= bestDist and HasEntityClearLosToEntity(ped, ent, 17) and canUseEntity(ent, ped) then
                    closestEnt, bestDist = ent, dist
                end
            end
        end
    end
    if closestEnt ~= 0 then doPose(closestEnt, 'medical') end
end)

-- ========= targets =========

---Register target model options for all supported models/poses.
local function registerTargets()
    -- gather all model ids
    ---@type integer[]
    local models = {}
    for model, _ in pairs(Models) do models[#models + 1] = model end

    Target.addModel(models, {
        {
            name = 'sp_chairs:medical',
            icon = 'fa-solid fa-bed',
            label = locale('laydown_medical'),
            distance = Config.target.distance,
            ---@param entity number
            canInteract = function(entity)
                return hasPose(entity, 'medical') and canUseEntity(entity, cache.ped)
            end,
            ---@param data {entity:number}
            onSelect = function(data) checkAndDo(data.entity, 'medical') end
        },
        {
            name = 'sp_chairs:chair',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair') end
        },
        {
            name = 'sp_chairs:chair2',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair2'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair2') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair2') end
        },
        {
            name = 'sp_chairs:chair3',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair3'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair3') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair3') end
        },
        {
            name = 'sp_chairs:chair4',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair4'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair4') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair4') end
        },
        {
            name = 'sp_chairs:stool',
            icon = 'fa-solid fa-circle-dot',
            label = locale('sit_stool'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'stool') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'stool') end
        },
        {
            name = 'sp_chairs:slots',
            icon = 'fa-solid fa-slot-machine',
            label = locale('use_slots'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'slots') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'slots') end
        },
        {
            name = 'sp_chairs:sunbed',
            icon = 'fa-solid fa-bed',
            label = locale('laydown_sunbed'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'sunbed') and canUseEntity(entity, cache.ped)
            end,
            onSelect = function(data) checkAndDo(data.entity, 'sunbed') end
        },
        -- Put person on medical (config-gated)
        {
            name = 'sp_chairs:put_person_medical',
            icon = 'fa-solid fa-user-plus',
            label = locale('put_on_bed'),
            distance = Config.target.distance,
            canInteract = function(entity)
                if not Config.allowPutOnMedicalBeds then return false end
                if not hasPose(entity, 'medical') then return false end
                if not canUseEntity(entity, cache.ped) then return false end
                local myPos = GetEntityCoords(cache.ped)
                local pid, ped = lib.getClosestPlayer(myPos, 2.0, false)
                return pid and DoesEntityExist(ped)
            end,
            onSelect = function()
                if not Config.allowPutOnMedicalBeds then return end
                local myPos = GetEntityCoords(cache.ped)
                local pid = lib.getClosestPlayer(myPos, 2.0, false)
                if pid then
                    TriggerServerEvent(Shared.serverEvent .. 'putOnMedical', GetPlayerServerId(pid))
                end
            end
        },
    })
end

---Target registration on resource start.
---@param res string
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    registerTargets()
end)
