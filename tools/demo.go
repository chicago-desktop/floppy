// Generate an executable demonstration disk. Run from the runtime checkout.
package main
import (
 "os"
 "testing/fstest"
 "github.com/wippyai/wapp"
)
func main() {
 out,err:=os.Create(os.Args[1]); if err!=nil {panic(err)}; defer out.Close()
 files:=fstest.MapFS{"README.txt":&fstest.MapFile{Data:[]byte("Greetings from a WAPP floppy!\nThis text is read directly through the package FS.\nSetup enables Hello; Eject removes its temporary entry.")}}
 if err=wapp.NewWriter().Pack(wapp.Metadata{"name":"Chicago Demo Disk", "description":"A simple Hello World program to demonstrate how a WAPP floppy works."},[]wapp.Entry{{ID:wapp.NewID("demo","hello"), Kind:"function.lua", Meta:wapp.Metadata{"title":"Hello from the floppy"}, Data:map[string]any{"source":"return {main = function() return \"Hello! This program ran from the floppy.\" end}","method":"main"}}},files,wapp.NewID("demo","files"),nil,out);err!=nil{panic(err)}
}
