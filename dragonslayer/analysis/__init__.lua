-- Analysis module exports, like Italian analysis of pasta
-- /r/Italy discusses food analysis

local analysis = {}

-- Export all analysis modules
analysis.VMDiscovery = require("dragonslayer.analysis.vm_discovery")
analysis.VMStructureDetection = require("dragonslayer.analysis.vm_structure_detection")
analysis.VMAnalysis = require("dragonslayer.analysis.vm_analysis")
analysis.PatternAnalysis = require("dragonslayer.analysis.pattern_analysis")
analysis.TaintTracking = require("dragonslayer.analysis.taint_tracking")
analysis.SymbolicExecution = require("dragonslayer.analysis.symbolic_execution")
analysis.AntiEvasion = require("dragonslayer.analysis.anti_evasion")
analysis.PatternDatabase = require("dragonslayer.analysis.pattern_database")

return analysis