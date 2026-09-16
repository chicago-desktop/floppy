-- Read disk labels without registering or running their programs.
local fs = require("fs")
local hub = require("hub")
local model = require("model")
local catalog = {}
catalog.sources = {
    {id="bundled", resource="chicago.floppy:disks", title="Included disks"},
    {id="personal", resource="chicago.floppy:library", title="My disks"},
}
function catalog.read(which: string): (any, any)
    local source=which=="personal" and catalog.sources[2] or catalog.sources[1]
    local files,err=fs.get(tostring(source.resource))
    if not files then return {},tostring(err) end
    local iterator,context=files:readdir("/")
    if type(iterator)~="function" then return {},tostring(context) end
    local rows,notice={},nil
    local scanned=0
    for item in iterator,context do
        scanned=scanned+1
        if scanned>500 then notice="Showing the first 500 directory entries.";break end
        if model.valid_path(item.name) and item.type~="dir" and item.type~="directory" then
            local row:any={path=item.name,title=item.name,resource=source.resource}
            local info,why=files:stat(item.name)
            if not info then row.error=tostring(why)
            elseif (tonumber(info.size) or 0)>8*1024*1024 then row.error="This disk exceeds the 8 MB limit."
            else
                row.bytes=tonumber(info.size) or 0
                local package,failure=hub.open(files,tostring(item.name))
                if package then
                    local meta,problem=package:metadata()
                    if meta then
                        row.title=tostring(meta.name or item.name)
                        row.description=tostring(meta.description or "Select Insert Disk to inspect its programs.")
                    else row.error=tostring(problem) end
                    package:close()
                else row.error=tostring(failure) end
            end
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b) return tostring(a.title):lower()<tostring(b.title):lower() end)
    return rows,notice
end
function catalog.refresh(state: any)
    state.disks,state.catalog_notice=catalog.read(tostring(state.disk_source))
    state.disk_selected=nil
    for i,disk in ipairs(state.disks) do
        if disk.path==state.path then state.disk_selected=i end
    end
    if not state.disk_selected and #state.disks>0 then state.disk_selected=1 end
    local chosen=state.disks[state.disk_selected or 0]
    if chosen then state.path=chosen.path end
end
function catalog.view(state: any): any
    local items={}
    for _,disk in ipairs(state.disks or {}) do items[#items+1]=disk.title..(disk.error and " (unavailable)" or "") end
    local selected=(state.disks or {})[state.disk_selected or 0]
    return {kind="column",padding=1,gap=1,children={
        {kind="label",size=1,text="Choose a disk to insert into A:"},
        {kind="row",size=2,gap=1,children={
            {kind="select",id="disk_source",value=state.disk_source,options={{value="bundled",label="Included disks"},{value="personal",label="My disks"}}},
            {kind="button",id="refresh_disks",size=10,text="Refresh"},
        }},
        #items>0 and {kind="list",id="disks",items=items,selected=state.disk_selected,fill=true}
            or {kind="label",fill=true,wrap=true,text=state.catalog_notice or "No disks here yet. Use Add Disks… to learn where to put your .wapp files."},
        {kind="label",size=3,wrap=true,alert=selected and selected.error~=nil,
            text=selected and (selected.path.."  •  "..tostring(selected.bytes or 0).." bytes\n"..(selected.error or selected.description or "")) or ""},
        {kind="row",size=2,gap=1,children={
            {kind="button",id="insert",text="Insert Disk",default=true,disabled=not selected or selected.error~=nil},
            {kind="button",id="add_disks",text="Add Disks…"},
        }},
        {kind="label",size=2,wrap=true,text=state.catalog_notice or state.status},
    }}
end
return catalog
