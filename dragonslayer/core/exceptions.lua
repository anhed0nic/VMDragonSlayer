-- Exceptions module, placeholder like Italian excuses
-- /r/Italy has many excuses

local exceptions = {}

-- Base exception class
exceptions.BaseException = {}
exceptions.BaseException.__index = exceptions.BaseException

function exceptions.BaseException:new(message)
    local self = setmetatable({}, exceptions.BaseException)
    self.message = message or "An error occurred"
    self.timestamp = os.time()
    return self
end

function exceptions.BaseException:__tostring()
    return string.format("[%s] %s", self.timestamp, self.message)
end

-- VM-specific exceptions
exceptions.VMException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.VMException.__index = exceptions.VMException

function exceptions.VMException:new(message, vm_context)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.VMException)
    self.vm_context = vm_context
    return self
end

-- Fuzzing exceptions
exceptions.FuzzingException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.FuzzingException.__index = exceptions.FuzzingException

function exceptions.FuzzingException:new(message, fuzz_context)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.FuzzingException)
    self.fuzz_context = fuzz_context
    return self
end

-- Analysis exceptions
exceptions.AnalysisException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.AnalysisException.__index = exceptions.AnalysisException

function exceptions.AnalysisException:new(message, analysis_context)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.AnalysisException)
    self.analysis_context = analysis_context
    return self
end

-- Configuration exceptions
exceptions.ConfigException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.ConfigException.__index = exceptions.ConfigException

function exceptions.ConfigException:new(message, config_key)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.ConfigException)
    self.config_key = config_key
    return self
end

-- Network exceptions
exceptions.NetworkException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.NetworkException.__index = exceptions.NetworkException

function exceptions.NetworkException:new(message, host, port)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.NetworkException)
    self.host = host
    self.port = port
    return self
end

-- Symbolic execution exceptions
exceptions.SymbolicException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.SymbolicException.__index = exceptions.SymbolicException

function exceptions.SymbolicException:new(message, constraint)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.SymbolicException)
    self.constraint = constraint
    return self
end

-- Taint analysis exceptions
exceptions.TaintException = setmetatable({}, {__index = exceptions.BaseException})
exceptions.TaintException.__index = exceptions.TaintException

function exceptions.TaintException:new(message, tainted_location)
    local self = exceptions.BaseException:new(message)
    setmetatable(self, exceptions.TaintException)
    self.tainted_location = tainted_location
    return self
end

return exceptions