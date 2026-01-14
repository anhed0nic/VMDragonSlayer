local utils = {}

utils.read_file = require("dragonslayer.utils.utils").read_file
utils.write_file = require("dragonslayer.utils.utils").write_file
utils.hex_dump = require("dragonslayer.utils.utils").hex_dump
utils.calculate_hash = require("dragonslayer.utils.utils").calculate_hash
utils.split_string = require("dragonslayer.utils.utils").split_string
utils.merge_tables = require("dragonslayer.utils.utils").merge_tables
utils.deep_copy = require("dragonslayer.utils.utils").deep_copy
utils.format_bytes = require("dragonslayer.utils.utils").format_bytes

return utils