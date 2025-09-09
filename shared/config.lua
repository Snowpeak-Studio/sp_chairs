---@class ChairsAnim
---@field dict string
---@field name string
---@field flag? number

---@class ChairsConfig
---@field target { distance: number }
---@field allowPutOnMedicalBeds boolean
---@field default ChairsAnim

local Config ---@type ChairsConfig
Config = {
    debug = false,
    versionCheck = true,
    target = {
        distance = 2.0
    },
    standUpKey = 'E',
    -- check data/keys.lua in sp_core for list of available keybinds.
    -- Toggle whether players can place others onto medical beds
    allowPutOnMedicalBeds = true,
    
    medicalLocksEntity = true,
    -- Fallback anim if a base/model doesn't specify one
    default = {
        dict = 'missfbi1',
        name = 'cpr_pumpchest_idle',
        flag = 1
    },
    wasabiPoliceCompat = false
}

return Config
