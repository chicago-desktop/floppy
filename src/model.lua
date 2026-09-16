-- The first executable disk contract supports standalone Lua functions.
-- Remapping IDs isolates mounts; imports, services and migrations need their
-- own linking and lifecycle contract before they can be supported.
local model = {}
function model.valid_path(path: any): boolean
    return type(path) == "string" and #path <= 128 and path:match("^[%w_%-][%w_.%-]*%.wapp$") ~= nil
end
function model.prepare(entries: any, namespace: string): (any, any)
    if type(entries) ~= "table" or #entries == 0 then return nil, "The disk has no executable entries." end
    if #entries > 32 then return nil, "The prototype supports at most 32 entries." end
    local out, seen = {}, {}
    for _, item in ipairs(entries) do
        if item.kind ~= "function.lua" then return nil, "Unsupported entry kind: " .. tostring(item.kind) end
        local data = item.data
        if type(data) ~= "table" or type(data.source) ~= "string" or type(data.method) ~= "string" then
            return nil, "A function needs packed Lua source and a method."
        end
        for key in pairs(data) do
            if key ~= "source" and key ~= "method" then return nil, "Unsupported function field: " .. tostring(key) end
        end
        local name = tostring(item.id):match(":([%w_]+)$")
        if not name or seen[name] then return nil, "Invalid or duplicate entry name." end
        seen[name] = true
        out[#out + 1] = {id = namespace .. ":" .. name, kind = "function.lua", data = data,
            meta = {title = tostring((item.meta or {}).title or name),
                floppy_window = (item.meta or {}).floppy_window == "canvas.v1" and "canvas.v1" or nil}}
    end
    return out, nil
end
return model
