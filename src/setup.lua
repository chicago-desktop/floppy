-- The setup ceremony is timed; registry changes belong to session.register.
local setup = {COPY_MS=8000,HOLD_MS=10000}
function setup.new(disk_label: any): any
    return {stage="welcome",name=tostring(disk_label or "Wippy"),destination="C:\\PROGRAM FILES\\WIPPY\\",
        percent=0}
end
function setup.destination(value: any): (any, any)
    if type(value)~="string" or #value>100 then return nil,"Enter a folder on C:." end
    local clean=value:upper():gsub("/","\\")
    if clean:sub(1,3)~="C:\\" or clean:find("[^A-Z0-9 _%.%-%\\:]") or clean:sub(3):find(":",1,true)
        or clean:find("..",1,true) then return nil,"Use a folder such as C:\\PROGRAM FILES\\WIPPY\\." end
    if clean:sub(-1)~="\\" then clean=clean.."\\" end
    if #clean<5 then return nil,"Choose a folder below C:\\." end
    return clean,nil
end
function setup.begin(wizard: any, now: number)
    wizard.stage,wizard.started,wizard.percent,wizard.error="copying",now,0,nil
end
function setup.progress(wizard: any, now: number): boolean
    local elapsed=math.max(0,now-(tonumber(wizard.started) or now))
    wizard.percent=math.min(99,math.floor(elapsed/setup.COPY_MS*99))
    return elapsed>=setup.COPY_MS+setup.HOLD_MS
end
local function label(text: any,size: integer): any
    return {kind="label",text=tostring(text or ""),size=size,size_px=size*16,wrap=true}
end
local function heading(text: string): any
    return {kind="picture",text=text,size=2,size_px=32}
end
local function button(id: string,text: string,disabled: boolean,default: boolean): any
    return {kind="button",id=id,text=text,disabled=disabled,default=default,size=10,size_px=81,width_px=75}
end
function setup.view(w: any, source: any): any
    local content={}
    if w.stage=="welcome" then
        content={heading("Welcome to Wippy Setup"),label("This wizard will guide you through setting up "..w.name..".",3),
            label("Before continuing, close any other applications you are running.",3),
            label("To continue, click Next.",2)}
    elseif w.stage=="destination" then
        content={heading("Choose Destination Location"),label("Choose a destination for the installation preview.",3),
            label("Destination folder (preview):",1),{kind="input",id="destination",text=w.destination,size=2,size_px=26},
            label(w.error or "To begin copying files, click Next.",2),
            label("Programs stay on the disk and are removed when you eject it.",3)}
    elseif w.stage=="copying" or w.stage=="failed" then
        local files={"SETUP.INF","WIPPY.EXE","README.TXT","PROGRAM.DAT","REGISTRY.DAT"}
        local file=files[math.min(#files,math.floor(w.percent/20)+1)]
        content={heading(w.stage=="failed" and "Setup could not finish" or "Copying Files…"),
            label("Source:",1),label("A:\\"..tostring(source),1),label("Destination:",1),label(w.destination..file,2),
            {kind="gauge",id="copy_progress",orient="horizontal",value=w.percent,ceiling=100,size=2,size_px=26},
            {kind="label",text=tostring(w.percent).."%",align="center",size=1,size_px=18},
            label(w.error or (w.percent==99 and "Updating system configuration…" or "Please wait while Setup copies the program files."),3)}
    elseif w.stage=="finish" then
        content={heading("Setup Complete"),label("Setup has finished setting up "..w.name..".",3),
            label("Would you like to restart your computer now?",2),
            {kind="radio",id="restart_now",text="Yes, I want to restart my computer now.",checked=false,disabled=true,size=1,size_px=24},
            {kind="radio",id="restart_later",text="No, I will restart my computer later.",checked=true,size=1,size_px=24},
            label("Click Finish to return to your floppy disk.",2)}

    end
    local next_text=w.stage=="finish" and "Finish" or (w.stage=="failed" and "Retry" or "Next >")
    return {kind="column",padding=1,padding_px=10,gap=0,children={
        {kind="row",gap=2,gap_px=16,children={
            {kind="group",style="sunken",background="#55a6a8",size=14,size_px=140,children={{kind="picture",image="chicago.floppy:images/setup",text="WIPPY\nSETUP",fill=true,align="center"}}},
            {kind="column",gap=0,children=content},
        }},
        {kind="separator",size=1,size_px=16},
        {kind="row",size=2,size_px=30,gap=1,gap_px=0,align="right",children={
            button("setup_back","< Back",w.stage~="destination",false),
            button("setup_next",next_text,w.stage=="copying",true),
            button("setup_cancel","Cancel",w.stage=="finish",false),
        }},
    }}
end
return setup
