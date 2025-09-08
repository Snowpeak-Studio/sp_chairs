
local resource = GetCurrentResourceName()
Shared = {
    resource = resource,
    actualResource = 'sp_chairs',
    event = resource .. ':',
    serverEvent = resource .. ':server:',
    callback = resource .. ':callback:',
    version = GetResourceMetadata(resource, 'version', 0),
    prefix = '^3[^4SP^3_^8Chairs^3]^0',
    debugMode = require('data.config').debug,
}
