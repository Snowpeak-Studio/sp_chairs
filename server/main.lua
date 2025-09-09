local Config = require('shared.config')

RegisterNetEvent(Shared.serverEvent .. 'putOnMedical', function(targetServerId)
    if not Config.allowPutOnMedicalBeds then return end
    if type(targetServerId) ~= 'number' then return end

    if Config.wasabiPoliceCompat and GetResourceState('wasabi_police') == 'started' then
        local state = Player(targetServerId).state
        if state.escorted == true then
            TriggerClientEvent('wasabi_police:stopEscorting', source, targetServerId)
            TriggerClientEvent('wasabi_police:escortedPlayer', targetServerId, source)
            state:set('escorted', false, true)
        end
    end

    TriggerClientEvent(Shared.event .. 'forceMedical', targetServerId)
end)

if Config.versionCheck then
    sp.version(Shared.resource, Shared.version)
end
