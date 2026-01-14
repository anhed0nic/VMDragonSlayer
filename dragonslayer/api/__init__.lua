local api = {}

api.APIServer = require("dragonslayer.api.server").APIServer
api.setup_routes = require("dragonslayer.api.endpoints").setup_routes
api.create_server = require("dragonslayer.api.endpoints").create_server

return api