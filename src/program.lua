-- A bounded canvas host. The disk owns its game state, rules and drawing commands.
local app=require("app")
local funcs=require("funcs")
local gfx=require("gfx")
local base64=require("base64")
local json=require("json")
local definition={interval="80ms",close_on_escape=true}
local function receive(state: any,event: any): boolean
    local result,err=state.call({event=event,state=state.model})
    if err or type(result)~="table" or type(result.canvas)~="table" then
        state.failure=tostring(err or "The disk returned an invalid frame.");return false
    end
    local canvas=result.canvas
    if canvas.width~=384 or canvas.height~=256 or type(canvas.rects)~="table" or #canvas.rects>1024 then
        state.failure="The disk returned an unsupported canvas.";return false
    end
    local raster=gfx.raster(384,256)
    raster:fill("#ffffff")
    for _,r in ipairs(canvas.rects) do
        if type(r)~="table" then state.failure="The disk returned an invalid drawing command.";return false end
        local x,y,w,h=math.tointeger(r.x),math.tointeger(r.y),math.tointeger(r.w),math.tointeger(r.h)
        if not x or not y or not w or not h or w<1 or h<1 or w>384 or h>256 or x< -384 or x>768 or y< -256 or y>512
            or type(r.color)~="string" or not r.color:match("^#%x%x%x%x%x%x$") then
            state.failure="The disk returned an invalid drawing command.";return false
        end
        raster:rect(x or 0,y or 0,w or 1,h or 1,tostring(r.color))
    end
    state.model,state.frame=result.state,result
    state.png=assert(base64.encode(assert(raster:encode("png"))))
    state.failure=nil
    return true
end
function definition.init(args: any): any
    if type(args)=="string" then args=json.decode(tostring(args)) end
    local entry=type(args)=="table" and args.entry or ""
    local state:any={title=type(args)=="table" and args.title or "Disk program"}
    if type(entry)~="string" or not entry:match("^chicago%.floppy%.disk_%x+:[%w_]+$") then
        state.failure="Insert the disk and launch this program from its drive.";return state
    end
    state.call=function(request) return funcs.call(entry,request) end
    receive(state,{type="init"})
    return state
end
function definition.title(state: any): string return tostring(state.title) end
function definition.view(state: any): any
    local frame=state.frame or {}
    return {kind="column",gap=0,children={
        {kind="statusbar",size=1,fields={{text="Distance: "..tostring(frame.score or "0 m")},{text="Lives: "..tostring(frame.lives or 0)},{text="Best: "..tostring(frame.best or 0).." m"}}},
        {kind="picture",png=state.png,fit="contain",fill=true,background="#ffffff",text="Ski needs pixel graphics (Kitty or Sixel)."},
        frame.active and {kind="label",size=2,text="← → Steer     Space Pause     R New Run",align="center"}
            or {kind="row",size=2,gap=1,children={{kind="button",id="pause",text="Start / Resume",disabled=frame.can_resume==false},{kind="button",id="restart",text="New Run"}}},
        {kind="label",size=2,text=state.failure or frame.status or "",wrap=true,alert=state.failure~=nil},
    }}
end
function definition.update(state: any,event: any,context: any): boolean
    if state.failure or not state.call then return false end
    if event.type=="key" and event.key_type=="esc" then return false end
    if event.type=="tick" and not (state.frame and state.frame.active) then return false end
    if event.type~="tick" and event.type~="key" and event.type~="activate" then return false end
    receive(state,event)
    return true
end
return {definition=definition,main=app.main(definition)}
