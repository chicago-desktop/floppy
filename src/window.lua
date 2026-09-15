local app = require("app")
local session = require("session")
local fs = require("fs")
local definition = {}
function definition.init(): any
    local state = session.new()
    state.path, state.selected = "hello.wapp", 1
    return state
end
function definition.view(state: any): any
    local entries = {}
    for _, entry in ipairs(state.entries or {}) do entries[#entries + 1] = tostring((entry.meta or {}).title or entry.id) end
    return {kind = "column", padding = 1, gap = 1, children = {
        {kind = "label", size = 1, text = state.label or "3 1/2 Floppy (A:)"},
        {kind = "input", id = "path", size = 2, text = state.path, disabled = state.package ~= nil},
        {kind = "row", size = 2, gap = 1, children = {
            {kind = "button", id = "insert", text = "Insert", disabled = state.package ~= nil},
            {kind = "button", id = "register", text = "Register", disabled = state.package == nil or state.registered},
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
    if action.type ~= "activate" then return false end
    local ok, err
    if action.id == "insert" then
        local source, why = fs.get("chicago.floppy:disks")
        if not source then state.status = tostring(why); return true end
        ok, err = session.insert(state, source, tostring(state.path))
    elseif action.id == "register" then ok, err = session.register(state)
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
