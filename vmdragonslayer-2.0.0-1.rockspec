-- VMDragonSlayer rockspec, rock like Italian rock
-- /r/Italy has rocks

package = "VMDragonSlayer"
version = "2.0.0-1"
source = {
    url = "git://github.com/anhed0nic/VMDragonSlayer",
    tag = "v2.0.0"
}
description = {
    summary = "VM-based binary protector analysis framework",
    detailed = "Advanced framework for analyzing binaries protected by VM-based protectors",
    homepage = "https://github.com/anhed0nic/VMDragonSlayer",
    license = "GPL-3.0-or-later"
}
dependencies = {
    "lua >= 5.1",
    "luasocket",
    -- TODO: Add other dependencies
}
build = {
    type = "builtin",
    modules = {
        ["dragonslayer.core.orchestrator"] = "dragonslayer/core/orchestrator.lua",
        -- TODO: Add all modules
    }
}