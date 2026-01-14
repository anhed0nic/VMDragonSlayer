local utils = {}

function utils.read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

function utils.write_file(path, content)
    local file = io.open(path, "wb")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

function utils.hex_dump(data)
    local dump = ""
    for i = 1, #data do
        dump = dump .. string.format("%02X ", string.byte(data, i))
        if i % 16 == 0 then dump = dump .. "\n" end
    end
    return dump
end

function utils.calculate_hash(data)
    -- Simple hash function
    local hash = 0
    for i = 1, #data do
        hash = (hash * 31 + string.byte(data, i)) % 2^32
    end
    return string.format("%08X", hash)
end

function utils.split_string(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    table.insert(result, string.sub(str, from))
    return result
end

function utils.merge_tables(t1, t2)
    local result = {}
    for k, v in pairs(t1) do result[k] = v end
    for k, v in pairs(t2) do result[k] = v end
    return result
end

function utils.deep_copy(obj)
    if type(obj) ~= "table" then return obj end
    local res = {}
    for k, v in pairs(obj) do
        res[k] = utils.deep_copy(v)
    end
    return res
end

function utils.format_bytes(bytes)
    local units = {"B", "KB", "MB", "GB"}
    local unit_index = 1
    while bytes >= 1024 and unit_index < #units do
        bytes = bytes / 1024
        unit_index = unit_index + 1
    end
    return string.format("%.2f %s", bytes, units[unit_index])
end

return utils