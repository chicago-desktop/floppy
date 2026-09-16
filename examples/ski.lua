-- Disk-owned game logic and pixel art. No runtime modules or external imports.
local game = {}
local function random(s,n)
    s.seed=(s.seed*48271)%2147483647
    return s.seed%n
end
local function fresh(best)
    local s={x=192,distance=0,lives=3,best=best or 0,phase="ready",seed=12347,tick=0,objects={},tracks={}}
    for i=1,12 do s.objects[i]={x=18+random(s,348),y=140+i*27,kind=i%4==0 and "rock" or "tree"} end
    return s
end
function game.main(request)
    request=request or {}
    local s=request.state or fresh(0)
    local event=request.event or {}
    local key=event.key_type=="runes" and event.key or (event.key_type or event.key or event.id)
    if event.type=="activate" then key=event.id end
    if event.action=="release" then key=nil end
    if key=="restart" or key=="r" then s=fresh(s.best);s.phase="skiing"
    elseif key=="pause" or key=="space" or event.key==" " then
        if s.phase=="ready" then s.phase="skiing"
        elseif s.phase=="skiing" then s.phase="paused"
        elseif s.phase=="paused" then s.phase="skiing" end
    elseif (key=="left" or key=="right") and s.phase=="skiing" then
        s.x=math.max(14,math.min(370,s.x+(key=="left" and -13 or 13)))
    end
    if event.type=="tick" then
        s.tick=s.tick+1
        if s.phase=="fallen" then
            s.recover=s.recover-1
            if s.recover<=0 then s.phase=s.lives>0 and "skiing" or "over";s.shield=20 end
        elseif s.phase=="skiing" then
            local speed=3+math.min(4,math.floor(s.distance/300))
            s.distance=s.distance+speed;s.best=math.max(s.best,s.distance)
            s.shield=math.max(0,(s.shield or 0)-1)
            for _,t in ipairs(s.tracks) do t.y=t.y-speed end
            s.tracks[#s.tracks+1]={x=s.x,y=94}
            if #s.tracks>28 then table.remove(s.tracks,1) end
            for _,o in ipairs(s.objects) do
                o.y=o.y-speed
                if o.y< -25 then o.y=270+random(s,65);o.x=16+random(s,352) end
                if s.shield==0 and math.abs(o.x-s.x)<(o.kind=="tree" and 12 or 10) and math.abs(o.y-92)<10 then
                    s.lives=s.lives-1;s.phase="fallen";s.recover=18;s.shield=20;break
                end
            end
        end
    end
    local commands={}
    local function rect(x,y,w,h,color)
        commands[#commands+1]={x=math.floor(x),y=math.floor(y),w=w,h=h,color=color}
    end
    for _,t in ipairs(s.tracks) do rect(t.x-5,t.y,1,5,"#d8e6ee");rect(t.x+5,t.y,1,5,"#d8e6ee") end
    for _,o in ipairs(s.objects) do
        local x,y=o.x,o.y
        if y>= -20 and y<=270 then
            if o.kind=="tree" then
                rect(x-10,y+3,23,4,"#d8e6ee");rect(x-2,y-1,4,9,"#804820")
                for tier=0,2 do
                    for line=0,5 do
                        local wide=3+line*2+tier*2
                        rect(x-math.floor(wide/2),y-24+tier*7+line,wide,2,line<2 and "#ffffff" or "#007838")
                    end
                end
                rect(x-5,y-6,4,2,"#005020")
            else
                rect(x-9,y+3,20,3,"#d8e6ee");rect(x-7,y-3,14,7,"#808890")
                rect(x-4,y-6,9,4,"#a8b0b8");rect(x-3,y-6,6,2,"#ffffff")
            end
        end
    end
    local x,y=s.x,92
    if s.phase=="fallen" or s.phase=="over" then
        rect(x-10,y,20,3,"#303070");rect(x-4,y-3,12,5,"#ff6020");rect(x+7,y-5,5,5,"#ffd0a0")
        rect(x-9,y+6,21,2,"#d02060")
    elseif (s.shield or 0)==0 or s.tick%2==0 then
        rect(x-7,y-2,2,15,"#d02060");rect(x+5,y-2,2,15,"#d02060")
        rect(x-5,y-5,4,10,"#202080");rect(x+1,y-5,4,10,"#202080")
        rect(x-6,y-14,12,11,"#ff6020");rect(x-10,y-10,4,3,"#ff6020");rect(x+6,y-10,4,3,"#ff6020")
        rect(x-4,y-20,8,7,"#ffd0a0");rect(x-5,y-23,10,4,"#0040c0")
        rect(x-13,y-10,1,14,"#404040");rect(x+12,y-10,1,14,"#404040")
    end
    local messages={ready="Press Space or New Run to start",skiing="",paused="Paused — press Space to continue",fallen="Ouch! Watch out for trees and rocks.",over="Run over — press R or New Run to try again"}
    return {state=s,canvas={width=384,height=256,background="#ffffff",rects=commands},
        status=messages[s.phase],score=tostring(s.distance).." m",lives=s.lives,best=s.best,can_resume=s.phase~="over",active=s.phase=="skiing" or s.phase=="fallen"}
end
return game
