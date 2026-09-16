local hub = require("hub")
local registry = require("registry")
local uuid = require("uuid")
local funcs = require("funcs")
local model = require("model")
local desktop = require("desktop")
local json = require("json")
local session = {}
function session.new(): any
    local token = assert(uuid.v4()):gsub("-", "")
    return {owner = "chicago.floppy:" .. token, namespace = "chicago.floppy.disk_" .. token,
        status = "Insert a disk to begin.", contents = "Drive is empty.", registered = false, windows = {},
        open_window=function(spec) return desktop.open_wait(spec,{timeout="1s"}) end,
        list_windows=function() return desktop.list({timeout="300ms"}) end,
        close_window=function(id) return desktop.close(id,{force=true}) end}
end
function session.insert(state: any, source: any, path: string): (boolean, any)
    if state.package then return false, "Eject the current disk first." end
    if not model.valid_path(path) then return false, "Choose a .wapp filename from the disks folder." end
    if type(hub.open) ~= "function" then return false, "This runtime needs local WAPP support (hub.open)." end
    local info, stat_err = source:stat(path)
    if not info then return false, tostring(stat_err) end
    if (tonumber(info.size) or 0) > 8 * 1024 * 1024 then return false, "The prototype accepts disks up to 8 MB." end
    local package, err = hub.open(source, path)
    if not package then return false, tostring(err) end
    local metadata, merr = package:metadata()
    local entries, eerr = package:entries()
    local resources, rerr = package:resources()
    if not metadata or not entries or not resources then
        package:close()
        return false, tostring(merr or eerr or rerr)
    end
    local contents = {}
    for _, resource in ipairs(resources) do
        contents[#contents + 1] = tostring(resource.id) .. " (" .. tostring(resource.file_count) .. " files)"
    end
    -- Optional preview, read through the package FS without registration.
    if resources[1] then
        local files = package:fs(resources[1].id)
        if files then
            local readme_info = files:stat("README.txt")
            if readme_info and tonumber(readme_info.size) and readme_info.size <= 16384 then
                local text = files:readfile("README.txt")
                if text then contents[#contents + 1] = tostring(text) end
            end
        end
    end
    state.package, state.entries, state.resources = package, entries, resources
    state.label = tostring(metadata.name or path)
    state.contents = table.concat(contents, "\n")
    state.status = "Disk inserted. Run Setup to enable its programs."
    return true, nil
end
function session.register(state: any): (boolean, any)
    if not state.package then return false, "Insert a disk first." end
    if state.registered then return true, nil end
    if type(registry.overlay) ~= "function" then return false, "This runtime needs registry.overlay support." end
    local entries, err = model.prepare(state.entries, tostring(state.namespace))
    if not entries then return false, err end
    local overlay, why = registry.overlay(tostring(state.owner))
    if not overlay then return false, tostring(why) end
    local changes = overlay:changes()
    for _, entry in ipairs(entries) do
        local added, failure = changes:create(entry)
        if not added then return false, tostring(failure) end
    end
    local applied, failure = changes:apply()
    if not applied then return false, tostring(failure) end
    state.registered, state.loaded = true, entries
    state.status = "Programs registered temporarily. Select one and press Run."
    return true, nil
end
function session.run(state: any, index: integer): (boolean, any)
    if not state.registered then return false, "Register the disk first." end
    local entry = state.loaded[index]
    if not entry then return false, "Select a program." end
    if (entry.meta or {}).floppy_window=="canvas.v1" then
        local opened,why=state.open_window({entry="chicago.floppy:program",title=entry.meta.title,
            window_type="tool",args=json.encode({entry=entry.id,title=entry.meta.title})})
        if not opened then return false,tostring(why) end
        state.windows[#state.windows+1]=opened.id
        state.status="Playing "..entry.meta.title..". Keep the disk inserted."
        return true,nil
    end
    state.busy = true
    local called, result, err = pcall(funcs.call, entry.id)
    state.busy = false
    if not called then return false, tostring(result) end
    if err then return false, tostring(err) end
    state.status = tostring(result)
    return true, nil
end
function session.eject(state: any): (boolean, any)
    if state.busy then return false, "The disk is in use." end
    if #(state.windows or {})>0 then
        local answer,why=state.list_windows()
        if not answer then return false,tostring(why) end
        local alive={}
        for _,window in ipairs(answer.windows or {}) do alive[window.id]=true end
        local remaining={}
        for _,id in ipairs(state.windows) do
            if alive[id] then
                local sent,err=state.close_window(id)
                if not sent then return false,tostring(err) end
                remaining[#remaining+1]=id
            end
        end
        state.windows=remaining
        if #remaining>0 then state.ejecting=true;return false,"Closing disk programs…" end
    end
    state.ejecting=false
    if state.registered then
        local overlay, err = registry.overlay(tostring(state.owner))
        if not overlay then return false, tostring(err) end
        local owned, read_err = overlay:entries()
        if not owned then return false, tostring(read_err) end
        if #owned > 0 then
            local changes = overlay:changes()
            local deleted, delete_err = changes:delete(owned)
            if not deleted then return false, tostring(delete_err) end
            local applied, why = changes:apply()
            if not applied then return false, tostring(why) end
        end
        state.registered, state.loaded = false, nil
    end
    if state.package then
        local ok, err = state.package:close()
        if not ok then return false, tostring(err) end
    end
    state.package, state.entries, state.resources, state.label = nil, nil, nil, nil
    state.contents, state.status = "Drive is empty.", "Disk ejected. Temporary entries removed."
    return true, nil
end
return session
