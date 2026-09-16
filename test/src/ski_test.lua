local test=require("test")
local session=require("session")
local program=require("program")
local funcs=require("funcs")
local registry=require("registry")
local fs=require("fs")
local gfx=require("gfx")
local base64=require("base64")
local render=require("render")
local rasters=require("rasters")
local ui=require("ui")
local tty=require("tty")
local process=require("process")
local channel=require("channel")
local time=require("time")
local json=require("json")
local function mount(): any
    local state=session.new()
    assert(session.insert(state,assert(fs.get("chicago.floppy:disks")),"ski.wapp"))
    assert(session.register(state))
    return state
end
local function define_tests()
    test.describe("Ski game on a WAPP floppy",function()
        test.it("loads game code from the disk, steers, pauses, collides and restarts",function()
            local disk=mount()
            local entry=disk.loaded[1].id
            test.eq(disk.loaded[1].meta.floppy_window,"canvas.v1")
            local frame=assert(funcs.call(entry,{event={type="init"}}))
            test.eq(frame.state.phase,"ready")
            frame=assert(funcs.call(entry,{state=frame.state,event={type="key",key_type="space"}}))
            test.eq(frame.state.phase,"skiing")
            local x=frame.state.x
            frame=assert(funcs.call(entry,{state=frame.state,event={type="key",key_type="left"}}))
            test.is_true(frame.state.x<x)
            frame=assert(funcs.call(entry,{state=frame.state,event={type="tick"}}))
            test.is_true(frame.state.distance>0)
            frame=assert(funcs.call(entry,{state=frame.state,event={type="activate",id="pause"}}))
            local distance=frame.state.distance
            frame=assert(funcs.call(entry,{state=frame.state,event={type="tick"}}))
            test.eq(frame.state.distance,distance)
            frame.state.phase="skiing";frame.state.shield=0
            frame.state.objects={{x=frame.state.x,y=95,kind="tree"}}
            frame=assert(funcs.call(entry,{state=frame.state,event={type="tick"}}))
            test.eq(frame.state.phase,"fallen");test.eq(frame.state.lives,2)
            frame=assert(funcs.call(entry,{state=frame.state,event={type="key",key_type="runes",key="r"}}))
            test.eq(frame.state.lives,3);test.eq(frame.state.distance,0)
            for tick=1,220 do
                frame=assert(funcs.call(entry,{state=frame.state,event={type="tick"}}))
                test.is_true(#frame.canvas.rects<=1024)
                test.is_true(#frame.state.objects<=12 and #frame.state.tracks<=28)
            end
            assert(session.eject(disk))
            test.is_nil(registry.get(entry))
        end)
        test.it("renders the disk-owned game through the window host and rejects oversized frames",function()
            local disk=mount()
            local state=program.definition.init({entry=disk.loaded[1].id,title="Ski"})
            test.is_nil(state.failure)
            program.definition.update(state,{type="activate",id="restart"},{})
            for tick=1,12 do program.definition.update(state,{type="tick"},{}) end
            test.is_nil(state.failure)
            local tree=program.definition.view(state)
            test.is_nil(ui.problem(tree))
            local font_files=assert(fs.get("chicago.shell.theme:fonts"))
            local fonts={face=assert(gfx.font(assert(font_files:readfile("LiberationSans-Regular.ttf")),{size=13,smooth=true}))}
            local store=rasters.store();store.begin()
            local image=assert(render.placement({id="ski",state_revision=1,content_state={sdk=1,revision=1,ui=tree}},
                {x=1,y=1,cols=56,rows=22},{w=10,h=20},fonts,store))
            assert(assert(fs.get("app:shots")):writefile("ski.png",assert(image.raster:encode("png"))))
            state.call=function() return {canvas={width=99999,height=256,rects={}}} end
            program.definition.update(state,{type="activate",id="restart"},{})
            test.not_nil(state.failure)
            assert(session.eject(disk))
        end)
        test.it("closes only the disk's windows before removing its functions",function()
            local disk=mount()
            local calls:any={closed={},alive=true}
            disk.open_window=function(spec) calls.spec=spec;return {id="ski-window"} end
            disk.list_windows=function() return {windows=calls.alive and {{id="ski-window"},{id="unrelated"}} or {{id="unrelated"}}} end
            disk.close_window=function(id) calls.closed[#calls.closed+1]=id;return true end
            assert(session.run(disk,1))
            test.eq(json.decode(calls.spec.args).entry,disk.loaded[1].id)
            local entry=disk.loaded[1].id
            local ok=session.eject(disk)
            test.is_false(ok);test.is_true(disk.ejecting)
            test.not_nil(registry.get(entry),"the game entry lives until its window has stopped")
            test.eq(#calls.closed,1);test.eq(calls.closed[1],"ski-window")
            calls.alive=false
            assert(session.eject(disk));test.is_nil(registry.get(entry))
        end)
        test.it("plays the disk game in a real window process",function()
            local disk=mount()
            local viewport=assert(tty.viewport({width=56,height=22}))
            local pid=assert(process.with_options({terminal=assert(viewport:grant())})
                :spawn_monitored("chicago.floppy:program","app:processes",json.encode({entry=disk.loaded[1].id,title="Ski"})))
            local function wait_for(text)
                local deadline=time.now():unix_nano()+4000000000
                while time.now():unix_nano()<deadline do
                    local snapshot=viewport:snapshot(-1)
                    local text_seen=snapshot and table.concat(snapshot.rows or {},"\n") or ""
                    if text_seen:find(text,1,true) then return end
                    channel.select({time.after("25ms"):case_receive()})
                end
                error("Game window did not show "..text)
            end
            wait_for("Press Space")
            assert(viewport:send({type="key",key_type="runes",key=" ",action="press"}))
            wait_for("Steer")
            assert(viewport:send({type="key",key_type="runes",key=" ",action="press"}))
            wait_for("Paused")
            assert(viewport:send({type="key",key_type="runes",key=" ",action="press"}))
            wait_for("Steer")
            assert(viewport:send({type="close"}))
            viewport:close();process.terminate(tostring(pid))
            assert(session.eject(disk))
        end)
    end)
end
local run_cases=test.run_cases(define_tests)
return {run=function(options) return run_cases(options) end}
