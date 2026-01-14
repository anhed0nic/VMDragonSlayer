local socket = require("socket")

local api = {}

api.APIServer = {}

function api.APIServer:new(port)
    local self = setmetatable({}, { __index = api.APIServer })
    self.port = port or 8080
    self.server = nil
    self.routes = {}
    return self
end

function api.APIServer:add_route(path, method, handler)
    self.routes[path .. ":" .. method] = handler
end

function api.APIServer:start()
    self.server = socket.bind("*", self.port)
    if not self.server then
        error("Could not bind to port " .. self.port)
    end
    self.server:settimeout(0)
    print("API Server started on port " .. self.port)
end

function api.APIServer:stop()
    if self.server then
        self.server:close()
        self.server = nil
    end
end

function api.APIServer:handle_request(client)
    local request = client:receive()
    if request then
        -- Parse simple HTTP request
        local method, path = request:match("(%w+) (%S+)")
        local handler = self.routes[path .. ":" .. method]
        if handler then
            local response = handler()
            client:send("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" .. response)
        else
            client:send("HTTP/1.1 404 Not Found\r\n\r\nNot Found")
        end
    end
    client:close()
end

function api.APIServer:run()
    while true do
        local client = self.server:accept()
        if client then
            self:handle_request(client)
        end
        socket.sleep(0.01)  -- Prevent busy waiting
    end
end

return api