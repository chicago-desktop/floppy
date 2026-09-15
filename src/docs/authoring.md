# Creating WAPP floppy disks

This is the authoring contract for agents creating disks for the Chicago floppy
prototype. This same document is embedded in the `readme` field of the registry
entry `chicago.floppy:definition`. Read that entry with `registry.get` when the
checkout is unavailable.

## Supported contract

- A disk is a WAPP archive, at most 8 MiB, with 1–32 executable entries.
- Every entry must be `function.lua`. Its data contains exactly `source` (packed
  Lua source text) and `method` (an exported function name).
- Use IDs such as `demo:hello`. Entry names contain ASCII letters, digits or
  underscores and must be unique across the entire disk, even across namespaces.
- `meta.title` optionally supplies the program label; package metadata `name`
  supplies the disk label.
- The method is called without arguments. Return a short string for the drive's
  result display. Export it from a returned table, for example:

```lua
return {main = function() return "Hello from my disk!" end}
```

Do not declare imports, modules, dependencies, services, policies, migrations,
processes or even an `ns.definition` among the disk's entries. Registration
rejects unsupported kinds and extra function data fields. This disk format is
smaller than a normal installable Wippy module. Use self-contained functions
that finish promptly; execution is synchronous and there is no cancellation UI.

## Build an archive

Use the WAPP writer version already pinned by the runtime checkout. Save the
following as `/tmp/make-my-disk.go`, then run from that checkout:

```sh
go run /tmp/make-my-disk.go /tmp/my-disk.wapp
```

```go
package main

import (
    "os"
    "testing/fstest"
    "github.com/wippyai/wapp"
)

func main() {
    if len(os.Args) != 2 { panic("usage: make-my-disk OUTPUT.wapp") }
    out, err := os.Create(os.Args[1])
    if err != nil { panic(err) }
    files := fstest.MapFS{
        "README.txt": &fstest.MapFile{Data: []byte("My first disk. Register, then Run Hello.")},
    }
    entries := []wapp.Entry{{
        ID: wapp.NewID("demo", "hello"),
        Kind: "function.lua",
        Meta: wapp.Metadata{"title": "Hello"},
        Data: map[string]any{
            "source": `return {main = function() return "Hello from my disk!" end}`,
            "method": "main",
        },
    }}
    err = wapp.NewWriter().Pack(wapp.Metadata{"name": "My First Disk"},
        entries, files, wapp.NewID("demo", "files"), nil, out)
    closeErr := out.Close()
    if err != nil { panic(err) }
    if closeErr != nil { panic(closeErr) }
}
```

The archive filesystem is a resource, not an `fs.*` executable entry. The drive
previews `README.txt` at the root of the first filesystem resource, up to 16 KiB.
Files are not registered globally or passed to the disk's functions.

The module's `tools/demo.go` and `make demo` also build a working `hello.wapp`.
Do not assume that packing an ordinary application with all its dependencies
produces a compatible floppy.

## Try and verify

1. Copy `my-disk.wapp` into the directory exposed by `chicago.floppy:disks`
   (the local module's `disks/` directory in the current setup).
2. Use a runtime with `hub.open(fs, path)` and `registry.overlay(owner)`.
3. As an administrator, open My Computer → 3 1/2 Floppy (A:).
4. Enter `my-disk.wapp` and click Insert. Check the label and README.
5. Click Register, select Hello, then Run. Check the expected returned string.
6. Click Eject. Check that the temporary functions are removed. Reinsert to
   verify that the same disk still works.

The filename must be a basename ending in `.wapp`, at most 128 characters, using
letters, digits, underscores, hyphens or dots, and starting with a letter,
digit, underscore or hyphen. Paths such as `../my-disk.wapp` are rejected.

Insert only opens and inspects the archive. Register validates all executable
entries, then remaps them into a fresh `chicago.floppy.disk_<uuid>` namespace.
Do not hard-code original IDs for calls between disk programs. Each drive
window owns its own mount; ejecting one does not remove another window's mount.
Eject removes only that mount's entries and closes the package. Normal window
close does the same. Forced process termination can leave temporary entries
until runtime restart. Permanent installation is not implemented.

## Troubleshooting

- Unsupported entry kind or function field: reduce the package to standalone
  functions with only `source` and `method` in their data.
- Invalid or duplicate entry name: use distinct ASCII identifier names.
- Missing Lua method: ensure the source returns a table exporting the exact
  name in `method`.
- Missing local WAPP support: use a runtime containing the local `hub.open` API.
- Test harness conflicts in the host: keep `test/**`, `app:**` and `app.env:**`
  excluded from the floppy module. Harness services are not disk content.

For module changes run `make test` and `make lint` with a compatible runtime.
Keep this guide aligned with `src/model.lua` and `src/session.lua`.
