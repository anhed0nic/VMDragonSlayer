local gpu = {}

gpu.GPUEngine = require("dragonslayer.gpu.engine").GPUEngine
gpu.MemoryManager = require("dragonslayer.gpu.memory_management").MemoryManager
gpu.Optimizer = require("dragonslayer.gpu.optimization").Optimizer
gpu.Profiler = require("dragonslayer.gpu.profiling").Profiler

return gpu