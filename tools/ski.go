// Build the game disk from its standalone Lua source.
package main
import (
 "os"
 "testing/fstest"
 "github.com/wippyai/wapp"
)
func main() {
 source,err:=os.ReadFile("../floppy/examples/ski.lua");if err!=nil {panic(err)}
 out,err:=os.Create(os.Args[1]);if err!=nil {panic(err)};defer out.Close()
 files:=fstest.MapFS{"README.txt":&fstest.MapFile{Data:[]byte("Ski — a downhill game for Wippy.\nRun Setup, then select Ski and press Run.\nLeft/Right: steer. Space: start/pause. R: new run.\nAvoid trees and rocks. Three falls end a run.\nKeep the floppy inserted while playing.")}}
 err=wapp.NewWriter().Pack(wapp.Metadata{"name":"Ski — Downhill Adventures", "description":"A downhill skiing game. Dodge trees and rocks; three falls end your run."},[]wapp.Entry{{ID:wapp.NewID("ski","game"),Kind:"function.lua",Meta:wapp.Metadata{"title":"Ski", "floppy_window":"canvas.v1"},Data:map[string]any{"source":string(source),"method":"main"}}},files,wapp.NewID("ski","files"),nil,out)
 if err!=nil {panic(err)}
}
