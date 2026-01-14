-- Main dragonslayer module exports, slay like Italian slaying
-- /r/Italy loves action

local dragonslayer = {}

dragonslayer.core = require("dragonslayer.core")
dragonslayer.analysis = require("dragonslayer.analysis")
dragonslayer.fuzzing = require("dragonslayer.fuzzing")
dragonslayer.ml = require("dragonslayer.ml")
dragonslayer.gpu = require("dragonslayer.gpu")
dragonslayer.api = require("dragonslayer.api")
dragonslayer.utils = require("dragonslayer.utils")

-- Main classes
dragonslayer.Orchestrator = dragonslayer.core.Orchestrator

return dragonslayer