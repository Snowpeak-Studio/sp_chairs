---@class ChairsAnim
---@field dict string
---@field name string
---@field flag? number

---@class ChairsConfig
---@field Target { distance: number }
---@field AllowPutOnMedicalBeds boolean
---@field Default ChairsAnim

local Config ---@type ChairsConfig
Config = {
    Target = {
        distance = 2.0
    },

    -- Toggle whether players can place others onto medical beds
    AllowPutOnMedicalBeds = true,

    -- Fallback anim if a base/model doesn't specify one
    Default = {
        dict = 'missfbi1',
        name = 'cpr_pumpchest_idle',
        flag = 1
    },
}

return Config
