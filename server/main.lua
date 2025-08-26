local Config = require 'shared.config'

RegisterNetEvent('sp_chairs:putOnMedical', function(targetServerId)
    if not Config.AllowPutOnMedicalBeds then return end
    if type(targetServerId) ~= 'number' then return end
    TriggerClientEvent('sp_chairs:forceMedical', targetServerId)
end)
