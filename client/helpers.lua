local Config = require('shared.config')

local Helpers = {}

-- ===== statebag + networking =====

---@param entity number
---@return number
function Helpers.ensureNetId(entity)
    if not DoesEntityExist(entity) then return 0 end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then
        NetworkRegisterEntityAsNetworked(entity)
        netId = NetworkGetNetworkIdFromEntity(entity)
    end
    if netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end
    return netId
end

---@param entity number
---@param pose string
---@return boolean
function Helpers.isPoseFree(entity, pose)
    if not DoesEntityExist(entity) then return false end
    local bag = Entity(entity).state[Shared.resource]
    if type(bag) ~= 'table' then return true end
    local owner = bag[pose]
    return owner == nil or owner == GetPlayerServerId(cache.playerId)
end

---@param entity number
---@param pose string
---@return boolean
function Helpers.reservePose(entity, pose)
    if not DoesEntityExist(entity) then return false end

    local netId = Helpers.ensureNetId(entity)
    if netId == 0 then return false end

    local st  = Entity(entity).state
    local bag = st[Shared.resource] or {}
    local me  = GetPlayerServerId(cache.playerId)

    -- if medical is active by someone else, block everything
    local medOwner = bag['medical']
    if Config.medicalLocksEntity and medOwner and medOwner ~= me then
        return false
    end

    if pose == 'medical' then
        -- medical claims the whole entity: fail if any other pose is owned by others
        for k, owner in pairs(bag) do
            if k ~= 'medical' and owner and owner ~= me then
                return false
            end
        end
    else
        -- chairs remain per-pose unless medical is active (handled above)
        local owner = bag[pose]
        if owner and owner ~= me then
            return false
        end
    end

    bag[pose] = me
    st:set(Shared.resource, bag, true) -- replicate
    return true
end


---@param entity number
---@param pose string
function Helpers.releasePose(entity, pose)
    if not DoesEntityExist(entity) then return end
    local st  = Entity(entity).state
    local bag = st[Shared.resource] or {}
    if bag[pose] == GetPlayerServerId(cache.playerId) then
        bag[pose] = nil
        st:set(Shared.resource, bag, true)
    end
end

-- ===== chairs utility =====

---@param ped number
---@param anim ChairsAnim|nil
function Helpers.playAnim(ped, anim)
    print('Helpers.playAnim', ped)
    print(sp.dump(anim))
    anim = anim or Config.default
    if not anim or not anim.dict or not anim.name then return end
    if lib.requestAnimDict(anim.dict, 10000) then
        lib.playAnim(ped, anim.dict, anim.name, 8.0, 8.0, -1, anim.flag or 0, 0.0, false, 0, false)
        RemoveAnimDict(anim.dict)
    end
end

---@param ped number
---@param entity number
---@param offset vector3
---@param rotation vector3
function Helpers.attachPedToEntity(ped, entity, offset, rotation)
    -- make sure we’re in the same room/interior and have collision
    local ex, ey, ez = table.unpack(GetEntityCoords(entity))
    RequestCollisionAtCoord(ex, ey, ez)
    SetEntityCoordsNoOffset(ped, ex, ey, ez, false, false, false)

    -- prep ped
    ClearPedTasksImmediately(ped)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityAsMissionEntity(ped, true, false)
    -- optional: block ai jitter
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- correct attach flags:
    -- p9=false, useSoftPinning=true, collision=false, isPed=true, vertexIndex=0, fixedRot=true
    AttachEntityToEntity(
        ped, entity, 0,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, true, false, true, 0, true
    )
end


---@param entity number
---@param camera PoseCamera|nil
---@return table|nil
function Helpers.createPoseCamera(entity, camera)
    if not camera then return nil end
    local origin = GetOffsetFromEntityInWorldCoords(entity, camera.offset.x, camera.offset.y, camera.offset.z)
    local target = GetOffsetFromEntityInWorldCoords(entity, camera.target.x, camera.target.y, camera.target.z)
    local cam = sp.camera.create({
        coords = origin,
        rotation = sp.coords.toRotation(sp.coords.normalize(target - origin), 1),
        fov = camera.fov or 55.0
    })
    cam:activate()
    return cam
end

return Helpers
