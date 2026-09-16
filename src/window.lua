local app = require("app")
local session = require("session")
local fs = require("fs")
local time = require("time")
local setup = require("setup")
local model = require("model")
local definition = {interval="200ms",close_on_escape=true}
function definition.init(): any
    local state = session.new()
    state.path, state.selected = "hello.wapp", 1
    state.now = function() return time.now():unix_nano()/1000000 end
    return state
end
function definition.title(state: any): string
    return state.wizard and "Wippy Setup Wizard" or "3½ Floppy (A:)"
end
function definition.view(state: any): any
    if state.wizard then return setup.view(state.wizard,state.path) end
    local entries = {}
    for _, entry in ipairs(state.entries or {}) do entries[#entries + 1] = tostring((entry.meta or {}).title or entry.id) end
    return {kind = "column", padding = 1, gap = 1, children = {
        {kind = "label", size = 1, text = state.label or "3½ Floppy (A:)"},
        {kind = "input", id = "path", size = 2, text = state.path, disabled = state.package ~= nil},
        {kind = "row", size = 2, gap = 1, children = {
            {kind = "button", id = "insert", text = "Insert", disabled = state.package ~= nil},
            {kind = "button", id = "setup", text = "Setup…", disabled = state.package == nil or state.registered},
            {kind = "button", id = "run", text = "Run", disabled = not state.registered},
            {kind = "button", id = "eject", text = "Eject", disabled = state.package == nil},
        }},
        {kind = "list", id = "entries", size = 3, items = entries, selected = state.selected},
        {kind = "label", text = state.contents},
        {kind = "label", size = 3, text = state.status},
    }}
end
function definition.update(state: any, action: any, context: any): any
    if action.type == "change" and action.id == "path" then state.path = tostring(action.value or ""); return true end
    if action.type == "select" and action.id == "entries" then state.selected = action.index; return true end
    if action.type == "close" then
        local ok, err = session.eject(state)
        if not ok then state.status = tostring(err); context.stay() end
        return true
    end
    local w=state.wizard
    if w then
        if action.type=="key" and action.key_type=="esc" and action.action~="release" then
            state.wizard=nil; return true
        end
        if action.type=="change" and action.id=="destination" and w.stage=="destination" then
            w.destination=tostring(action.value or "");w.error=nil;return true
        end
        if action.type=="tick" then
            if w.stage=="copying" then
                if setup.progress(w,(tonumber(state.now()) or 0)) then
                    -- One commit, only after the cancellable copy ceremony finishes.
                    local installed, why=session.register(state)
                    if installed then w.stage,w.percent="finish",100
                    else w.stage,w.error="failed",tostring(why) end
                end
                return true

            end
            return false
        end
        if action.type~="activate" then return false end
        if action.id=="setup_cancel" and w.stage~="finish" then
            state.wizard=nil;state.status="Setup cancelled. The disk is still inserted."
        elseif action.id=="setup_back" and w.stage=="destination" then w.stage,w.error="welcome",nil
        elseif action.id=="setup_next" then
            if w.stage=="welcome" then w.stage="destination"
            elseif w.stage=="destination" or w.stage=="failed" then
                local destination, why=setup.destination(w.destination)
                if not destination then w.error=why;return true end
                local ready, failure=model.prepare(state.entries,tostring(state.namespace))
                if not ready then w.error=tostring(failure);return true end
                w.destination=destination;setup.begin(w,(tonumber(state.now()) or 0))
            elseif w.stage=="finish" then
                state.wizard=nil
            end
        else return false end
        return true
    end
    if action.type ~= "activate" then return false end
    local ok, err
    if action.id == "insert" then
        local source, why = fs.get("chicago.floppy:disks")
        if not source then state.status = tostring(why); return true end
        ok, err = session.insert(state, source, tostring(state.path))
    elseif action.id == "setup" then
        if not state.package or state.registered then return false end
        state.wizard=setup.new(state.label);return true
    elseif action.id == "run" then ok, err = session.run(state, math.tointeger(state.selected) or 1)
    elseif action.id == "eject" then ok, err = session.eject(state)
    else return false end
    if not ok then state.status = tostring(err) end
    return true
end
function definition.dispose(state: any)
    local ok, err = session.eject(state)
    if not ok then error("Disk cleanup failed: " .. tostring(err)) end
end
return {definition = definition, main = app.main(definition)}
