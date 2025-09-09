---@type table
local Config  = require('shared.config')
---@type BasesMap
local Bases   = require('shared.bases')
---@type ModelsMap
local Models  = require('shared.models')
local Keys    = require('@sp_core.data.keys')
local Notify  = require('@sp_core.bridge.shared').load('ui.notify')
local TextUI  = require('@sp_core.bridge.shared').load('ui.textUI')
local Target  = require('@sp_core.bridge.shared').load('target')
local Helpers = require('client.helpers')
local cachedCoords = nil

-- ========= helpers (model/pose) =========

---@param entity number
---@param pose string
---@return boolean
local function hasPose(entity, pose)
    ---@type table<string, PoseEntry>|nil
    local t = Models[GetEntityModel(entity)]
    return t ~= nil and t[pose] ~= nil
end

---Execute a pose (per-entity statebag reserve -> attach -> anim -> camera -> release)
---@param entity number
---@param baseName string
local function doPose(entity, baseName)
    if not DoesEntityExist(entity) then return end

    -- fast local read
    if not Helpers.isPoseFree(entity, baseName) then
        Notify({ color = 'negative', icon = 'fa-solid fa-circle-xmark', message = locale('occupied') })
        return
    end
    -- optimistic reserve on this entity's statebag
    if not Helpers.reservePose(entity, baseName) then
        Notify({ color = 'negative', icon = 'fa-solid fa-circle-xmark', message = locale('occupied') })
        return
    end

    local ped      = cache.ped
    local model    = GetEntityModel(entity)
    local perModel = Models[model] or {}
    local entry    = perModel[baseName]
    local base     = Bases[baseName]
    if not entry or not base then
        Helpers.releasePose(entity, baseName)
        return
    end

    local offset   = entry.offset or vector3(0.0, 0.0, 0.0)
    local rotation = entry.rotation or vector3(0.0, 0.0, 0.0)
    local anim     = entry.anim or base.anim or Config.default
    cachedCoords = vec4(GetEntityCoords(cache.ped), GetEntityHeading(cache.ped))
    Helpers.attachPedToEntity(ped, entity, offset, rotation)
    Helpers.playAnim(ped, anim)

    local cam = Helpers.createPoseCamera(entity, entry.camera)
    TextUI.show('[' .. Config.standUpKey .. '] ' .. locale('getup'), {
        type = 'inform', icon = 'fa-solid fa-chair', position = 'right-center'
    })

    CreateThread(function()
        while DoesEntityExist(entity) and IsEntityAttachedToEntity(ped, entity) do
            if IsControlJustReleased(0, Keys[Config.standUpKey]) or IsDisabledControlJustPressed(0, Keys[Config.standUpKey]) then
                DetachEntity(ped, true, true)
                FreezeEntityPosition(ped, false)
                ClearPedTasksImmediately(ped)
                SetEntityCoords(cache.ped, cachedCoords.x, cachedCoords.y, cachedCoords.z - 1.0)
                SetEntityHeading(cache.ped, cachedCoords.w)
                cachedCoords = nil
                TextUI.hide()
                if cam then
                    cam:remove(); cam = nil
                end
                break
            end
            Wait(0)
        end
        if cam then
            cam:remove(); cam = nil
        end
        Helpers.releasePose(entity, baseName)
    end)
end

---Client-side trigger with per-entity bag check
---@param entity number
---@param pose string
local function checkAndDo(entity, pose)
    if not DoesEntityExist(entity) then return end
    if not hasPose(entity, pose) then return end
    if not Helpers.isPoseFree(entity, pose) then
        Notify({ color = 'negative', icon = 'fa-solid fa-circle-xmark', message = locale('occupied') })
        return
    end
    doPose(entity, pose)
end

-- ========= events =========

RegisterNetEvent(Shared.event .. 'forceMedical', function()
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local closestEnt, bestDist = 0, 2.0
    for model, poses in pairs(Models) do
        if poses.medical then
            local ent = GetClosestObjectOfType(pos.x, pos.y, pos.z, 10.0, model, false, false, false)
            if ent ~= 0 then
                local dist = #(GetEntityCoords(ent) - pos)
                if dist <= bestDist and HasEntityClearLosToEntity(ped, ent, 17) and Helpers.isPoseFree(ent, 'medical') then
                    closestEnt, bestDist = ent, dist
                end
            end
        end
    end
    if closestEnt ~= 0 then doPose(closestEnt, 'medical') end
end)

-- ========= targets =========

local function registerTargets()
    local models = {}
    for model, _ in pairs(Models) do models[#models + 1] = model end

    Target.addModel(models, {
        {
            name = 'sp_chairs:medical',
            icon = 'fa-solid fa-bed',
            label = locale('laydown_medical'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'medical') and Helpers.isPoseFree(entity, 'medical')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'medical') end
        },
        {
            name = 'sp_chairs:chair',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair') and Helpers.isPoseFree(entity, 'chair')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair') end
        },
        {
            name = 'sp_chairs:chair2',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair2'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair2') and Helpers.isPoseFree(entity, 'chair2')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair2') end
        },
        {
            name = 'sp_chairs:chair3',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair3'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair3') and Helpers.isPoseFree(entity, 'chair3')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair3') end
        },
        {
            name = 'sp_chairs:chair4',
            icon = 'fa-solid fa-chair',
            label = locale('sit_chair4'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'chair4') and Helpers.isPoseFree(entity, 'chair4')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'chair4') end
        },
        {
            name = 'sp_chairs:stool',
            icon = 'fa-solid fa-circle-dot',
            label = locale('sit_stool'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'stool') and Helpers.isPoseFree(entity, 'stool')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'stool') end
        },
        {
            name = 'sp_chairs:slots',
            icon = 'fa-solid fa-slot-machine',
            label = locale('use_slots'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'slots') and Helpers.isPoseFree(entity, 'slots')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'slots') end
        },
        {
            name = 'sp_chairs:sunbed',
            icon = 'fa-solid fa-bed',
            label = locale('laydown_sunbed'),
            distance = Config.target.distance,
            canInteract = function(entity)
                return hasPose(entity, 'sunbed') and Helpers.isPoseFree(entity, 'sunbed')
            end,
            onSelect = function(data) checkAndDo(data.entity, 'sunbed') end
        },
        {
            name = 'sp_chairs:put_person_medical',
            icon = 'fa-solid fa-user-plus',
            label = locale('put_on_bed'),
            distance = Config.target.distance,
            canInteract = function(entity)
                if not Config.allowPutOnMedicalBeds then return false end
                if not hasPose(entity, 'medical') then return false end
                if not Helpers.isPoseFree(entity, 'medical') then return false end
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

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    registerTargets()
end)



AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = cache.ped
    local ent = IsEntityAttached(ped) and GetEntityAttachedTo(ped)
    if ent and ent ~= 0 then
        for _, pose in ipairs({ 'chair', 'chair2', 'chair3', 'chair4', 'stool', 'sunbed', 'medical', 'slots' }) do
            Helpers.releasePose(ent, pose)
        end
    end
end)
