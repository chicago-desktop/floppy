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
    return {kind="label",text=tostring(text or ""),size=size,wrap=true}
end
local function heading(text: string): any
    return {kind="picture",text=text,size=2,size_px=32}
end
local function icon(name: string): any
    return {kind="row",size=4,size_px=74,children={
        {kind="label",text=""},{kind="image",image=name,icon="▣",size=4,size_px=32},{kind="label",text=""}}}
end
local function button(id: string,text: string,disabled: boolean,default: boolean): any
    return {kind="button",id=id,text=text,disabled=disabled,default=default,size=10,size_px=81,width_px=75}
end
function setup.view(w: any, source: any): any
    local content={}
    if w.stage=="welcome" then
        content={heading("Welcome to the Wippy Setup Wizard"),label("This wizard will guide you through setting up "..w.name..".",4),
            label("It is recommended that you close other applications before continuing.",3),
            label("Click Next to continue, or Cancel to exit Setup.",3),
            label("Disk programs remain available until this disk is ejected.",2)}
    elseif w.stage=="destination" then
        content={heading("Choose Destination Location"),label("Setup will use the following destination in the installation preview.",3),
            label("Destination folder:",1),{kind="input",id="destination",text=w.destination,size=2},
            label(w.error or "Choose a folder, then click Next to begin Setup.",3),
            label("This is a simulated copy. No files are written to C:; programs run from this disk.",3)}
    elseif w.stage=="copying" or w.stage=="failed" then
        local files={"SETUP.INF","WIPPY.EXE","README.TXT","PROGRAM.DAT","REGISTRY.DAT"}
        local file=files[math.min(#files,math.floor(w.percent/20)+1)]
        content={heading(w.stage=="failed" and "Setup could not finish" or "Copying Files…"),
            label("Source: A:\\"..tostring(source),2),label("Destination: "..w.destination..file,3),
            {kind="gauge",id="copy_progress",orient="horizontal",value=w.percent,ceiling=100,size=2,size_px=26},
            {kind="label",text=tostring(w.percent).."%",align="center",size=1},
            label(w.error or (w.percent==99 and "Updating system configuration…" or "Please wait while Setup copies the program files."),3)}
    elseif w.stage=="finish" then
        content={heading("Setup Complete"),label("Setup has finished setting up "..w.name..".",3),
            label("Would you like to restart your computer now?",2),
            {kind="radio",id="restart_now",text="Yes, I want to restart my computer now.",checked=false,disabled=true,size=2},
            {kind="radio",id="restart_later",text="No, I will restart my computer later.",checked=true,size=2},
            label("No restart is required. Click Finish to return to your floppy disk.",3)}

    end
    local next_text=w.stage=="finish" and "Finish" or (w.stage=="failed" and "Retry" or "Next >")
    return {kind="column",padding=1,padding_px=12,gap=0,children={
        {kind="row",gap=2,gap_px=18,children={
            {kind="group",style="sunken",background="#008080",size=12,size_px=120,children={icon("my_computer"),icon("floppy"),icon("drive")}},
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
