local test = require("test")
local window = require("window")
local ui = require("ui")
local session = require("session")
local model = require("model")
local setup = require("setup")
local render = require("render")
local rasters = require("rasters")
local gfx = require("gfx")
local fs = require("fs")
local registry = require("registry")
local tty = require("tty")
local process = require("process")
local channel = require("channel")
local time = require("time")
local sources = require("sources")
local function define_tests()
    test.describe("WAPP floppy lifecycle", function()
        test.it("discovers A: and runs the lifecycle in a real window process", function()
            local root = assert(sources.list("", {}))
            local found = false
            for _, item in ipairs(root.objects) do
                if item.id == "chicago.floppy:drive" then
                    test.eq(item.open.entry, "chicago.floppy:window")
                    found = true
                end
            end
            test.is_true(found, "Explorer discovers the drive provider")
            local view = assert(tty.viewport({width = 62, height = 22}))
            local pid = assert(process.with_options({terminal = assert(view:grant())})
                :spawn_monitored("chicago.floppy:window", "app:processes",{path="hello.wapp"}))
            local function wait_for(text, budget)
                local shown = ""
                local deadline = time.now():unix_nano() + (budget or 5)*1000000000
                while time.now():unix_nano() < deadline do
                    local snap = view:snapshot(-1)
                    shown = snap and table.concat(snap.rows or {}, "\n") or ""
                    if shown:find(text, 1, true) then return end
                    channel.select({time.after("25ms"):case_receive()})
                end
                error("Window did not show " .. text .. ":\n" .. shown)
            end
            local layout_state=window.definition.init({path="hello.wapp"})
            local function click(id)
                local state = layout_state
                local plan = ui.plan(window.definition.view(state), 62, 22, ui.interaction())
                local rect = plan.by_id[id].rect
                assert(view:send({type = "mouse", action = "press", button = "left", x = rect.x + 1, y = rect.y}))
                assert(view:send({type = "mouse", action = "release", button = "left", x = rect.x + 1, y = rect.y}))
            end
            wait_for("hello.wapp")
            wait_for("Insert a disk")
            click("insert")
            wait_for("Chicago Demo Disk")
            click("setup")
            wait_for("Welcome to Wippy Setup")
            layout_state.wizard=setup.new("Chicago Demo Disk")
            click("setup_next")
            wait_for("Choose Destination Location")
            layout_state.wizard.stage="destination"
            click("setup_next")
            wait_for("Copying Files")
            wait_for("99%",12)
            wait_for("Setup Complete",14)
            layout_state.wizard.stage="finish"
            click("setup_next")
            layout_state.wizard=nil
            wait_for("Programs registered temporarily")
            click("run")
            wait_for("This program ran from the floppy")
            click("eject")
            wait_for("Temporary entries removed")
            assert(view:send({type = "close"}))
            view:close()
            process.terminate(tostring(pid))
        end)

        test.it("reads the demo through package FS, renders it, ejects and reinserts", function()
            local definition = window.definition
            local state = definition.init({path="hello.wapp"})
            local context = {width = 62, height = 22, stay = function() end}
            local before = assert(registry.find({[".kind"] = "function.lua"}))
            definition.update(state, {type = "activate", id = "insert"}, context)
            test.not_nil(state.package, tostring(state.status))
            test.eq(state.label, "Chicago Demo Disk")
            test.is_true(state.contents:find("Greetings from a WAPP floppy!", 1, true) ~= nil, tostring(state.contents))
            test.eq(#assert(registry.find({[".kind"] = "function.lua"})), #before)
            local clock:any={now=0}
            state.now=function() return clock.now end
            definition.update(state, {type="activate",id="setup"},context)
            definition.update(state, {type="activate",id="setup_next"},context)
            definition.update(state, {type="activate",id="setup_next"},context)
            clock.now=setup.COPY_MS+setup.HOLD_MS
            definition.update(state,{type="tick"},context)
            test.eq(state.wizard.stage,"finish")
            definition.update(state,{type="activate",id="setup_next"},context)
            test.is_true(state.registered, tostring(state.status))
            local entry = state.loaded[1].id
            test.not_nil(registry.get(entry))
            test.is_nil(registry.get("demo:hello"), "the original namespace is not registered")
            definition.update(state, {type = "activate", id = "run"}, context)
            test.eq(state.status, "Hello! This program ran from the floppy.")
            local tree = definition.view(state)
            test.is_nil(ui.problem(tree))
            local font_files = assert(fs.get("chicago.shell.theme:fonts"))
            local fonts = {face = assert(gfx.font(assert(font_files:readfile("LiberationSans-Regular.ttf")), {size = 13, smooth = true}))}
            local store = rasters.store()
            store.begin()
            local placed = assert(render.placement({id = "floppy", state_revision = 1,
                content_state = {sdk = 1, revision = 1, interaction = ui.interaction(), ui = tree}},
                {x = 1, y = 1, cols = 62, rows = 22}, {w = 10, h = 20}, fonts, store))
            assert(assert(fs.get("app:shots")):writefile("floppy.png", assert(placed.raster:encode("png"))))
            local package = state.package
            definition.update(state, {type = "activate", id = "eject"}, context)
            test.is_nil(state.package)
            test.is_nil(registry.get(entry), "eject removes the mount-owned entry")
            local entries, closed = package:entries()
            test.is_nil(entries)
            test.not_nil(closed)
            definition.update(state, {type = "activate", id = "insert"}, context)
            test.not_nil(state.package, tostring(state.status))
            definition.dispose(state)
            test.is_nil(state.package)
        end)
        test.it("keeps the 99 percent pause cancellable and commits only once after ten seconds",function()
            local state=window.definition.init({path="hello.wapp"})
            local clock:any={now=1000}
            state.now=function() return clock.now end
            local context={stay=function() end}
            local function act(id) window.definition.update(state,{type="activate",id=id},context) end
            act("insert");act("setup");act("setup_next")
            window.definition.update(state,{type="change",id="destination",value="D:\\BAD"},context)
            act("setup_next");test.eq(state.wizard.stage,"destination");test.not_nil(state.wizard.error)
            window.definition.update(state,{type="change",id="destination",value="C:\\GAMES\\WIPPY"},context)
            act("setup_back");test.eq(state.wizard.stage,"welcome")
            act("setup_next");act("setup_next")
            test.eq(state.wizard.stage,"copying")
            clock.now=1000+setup.COPY_MS
            window.definition.update(state,{type="tick"},context)
            test.eq(state.wizard.percent,99);test.is_false(state.registered)
            clock.now=clock.now+setup.HOLD_MS-1
            window.definition.update(state,{type="tick"},context)
            test.eq(state.wizard.percent,99);test.is_false(state.registered)
            window.definition.update(state,{type="key",key_type="esc"},context)
            test.is_nil(state.wizard);test.not_nil(state.package)
            clock.now=clock.now+100000
            window.definition.update(state,{type="tick"},context)
            test.is_false(state.registered,"cancelled timers cannot register a disk")
            act("setup");act("setup_next");act("setup_next")
            clock.now=clock.now+setup.COPY_MS+setup.HOLD_MS
            window.definition.update(state,{type="tick"},context)
            test.eq(state.wizard.stage,"finish");test.is_true(state.registered)
            local owned=assert(registry.overlay(state.owner)):entries()
            window.definition.update(state,{type="tick"},context)
            test.eq(#assert(registry.overlay(state.owner)):entries(),#owned)
            act("setup_next");test.is_nil(state.wizard)
            test.is_true(state.registered,"Finish preserves the installed overlay")
            window.definition.dispose(state)
        end)
        test.it("reports registration failures and renders every wizard page at two pixel sizes",function()
            local state=window.definition.init({path="hello.wapp"})
            local clock:any={now=0}
            state.now=function() return clock.now end
            local context={stay=function() end}
            local function act(id) window.definition.update(state,{type="activate",id=id},context) end
            act("insert");act("setup");act("setup_next");act("setup_next")
            state.entries[1].kind="process.lua"
            clock.now=setup.COPY_MS+setup.HOLD_MS
            window.definition.update(state,{type="tick"},context)
            test.eq(state.wizard.stage,"failed");test.not_nil(state.wizard.error)
            test.is_false(state.registered)
            act("setup_cancel");test.is_nil(state.wizard);test.not_nil(state.package)
            act("setup")
            local font_files=assert(fs.get("chicago.shell.theme:fonts"))
            local fonts={face=assert(gfx.font(assert(font_files:readfile("LiberationSans-Regular.ttf")),{size=13,smooth=true})),
                bold=assert(gfx.font(assert(font_files:readfile("LiberationSans-Bold.ttf")),{size=13,smooth=true}))}
            for _,stage in ipairs({"welcome","destination","copying","finish","failed"}) do
                state.wizard.stage=stage
                state.wizard.error=stage=="failed" and "Unsupported entry kind: process.lua" or nil
                state.wizard.percent=99
                local tree=window.definition.view(state)
                test.is_nil(ui.problem(tree))
                for _,cell in ipairs({{8,16},{10,20}}) do
                    local interaction=ui.interaction()
                    local plan=ui.plan(tree,52,20,interaction,{cell={w=cell[1],h=cell[2]}})
                    test.not_nil(plan.by_id.setup_next)
                    if stage=="finish" then test.is_true(plan.by_id.restart_now.node.disabled);test.is_true(plan.by_id.restart_later.node.checked) end
                    for _,item in ipairs(plan.items) do
                        if item.node.kind=="image" then
                            test.is_true(item.rect.w*cell[1]>=32 and item.rect.h*cell[2]>=32,"sidebar icons fit at "..stage.." "..cell[1])
                        end
                        test.is_true(item.rect.x>=1 and item.rect.y>=1 and item.rect.x+item.rect.w<=53 and item.rect.y+item.rect.h<=21)
                    end
                    local store=rasters.store();store.begin()
                    local image=assert(render.placement({id="setup",state_revision=1,content_state={sdk=1,revision=1,interaction=interaction,ui=tree}},
                        {x=1,y=1,cols=52,rows=20},{w=cell[1],h=cell[2]},fonts,store))
                    assert(assert(fs.get("app:shots")):writefile("setup_"..stage.."_"..tostring(cell[1])..".png",assert(image.raster:encode("png"))))
                end
            end
            window.definition.dispose(state)
            test.is_nil(setup.destination("C:\\..\\WIPPY"))
            test.is_nil(setup.destination("C:\\"))
        end)
        test.it("isolates two mounts and removes only the ejected mount", function()
            local source = assert(fs.get("chicago.floppy:disks"))
            local first, second = session.new(), session.new()
            assert(session.insert(first, source, "hello.wapp"))
            assert(session.insert(second, source, "hello.wapp"))
            assert(session.register(first))
            assert(session.register(second))
            test.is_true(first.loaded[1].id ~= second.loaded[1].id)
            local first_id, second_id = first.loaded[1].id, second.loaded[1].id
            first.busy = true
            local ok = session.eject(first)
            test.is_false(ok)
            test.not_nil(registry.get(first_id))
            first.busy = false
            assert(session.eject(first))
            test.is_nil(registry.get(first_id))
            test.not_nil(registry.get(second_id))
            assert(session.run(second, 1))
            assert(session.eject(second))
            test.is_nil(registry.get(second_id))
        end)
        test.it("refuses unsupported dependencies before applying any records", function()
            local state = session.new()
            assert(session.insert(state, assert(fs.get("chicago.floppy:disks")), "hello.wapp"))
            state.entries[#state.entries + 1] = {id = "demo:bad", kind = "ns.dependency", data = {}}
            local ok, why = session.register(state)
            test.is_false(ok)
            test.not_nil(why)
            test.is_false(state.registered)
            test.eq(#assert(registry.overlay(state.owner)):entries(), 0)
            assert(session.eject(state))
            test.is_false(model.valid_path("../hello.wapp"))
            test.is_false(model.valid_path("/tmp/hello.wapp"))
        end)
        test.it("an execution error leaves the disk ejectable", function()
            local state = session.new()
            assert(session.insert(state, assert(fs.get("chicago.floppy:disks")), "hello.wapp"))
            state.entries[1].data.source = 'return {main = function() error("demo failure") end}'
            assert(session.register(state))
            local id = state.loaded[1].id
            local ok, why = session.run(state, 1)
            test.is_false(ok)
            test.not_nil(why)
            test.is_false(state.busy)
            assert(session.eject(state))
            test.is_nil(registry.get(id))
        end)
    end)
end
local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
