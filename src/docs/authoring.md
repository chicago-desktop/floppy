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
        "README.txt": &fstest.MapFile{Data: []byte("My first disk. Run Setup, then Run Hello.")},
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
3. As an administrator, open My Computer → 3½ Floppy (A:).
4. Enter `my-disk.wapp` and click Insert. Check the label and README.
5. Click Setup, continue through the destination page and wait for copying, including
   the ten-second pause at 99%. Click Finish, select Hello, then Run. Check the
   expected returned string.
6. Click Eject. Check that the temporary functions are removed. Reinsert to
   verify that the same disk still works.

The filename must be a basename ending in `.wapp`, at most 128 characters, using
letters, digits, underscores, hyphens or dots, and starting with a letter,
digit, underscore or hyphen. Paths such as `../my-disk.wapp` are rejected.

The wizard's destination and copying are simulated; no files are written to C:.
The completion screen never restarts the desktop or operating system.

Insert only opens and inspects the archive. Setup validates all executable
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

## Window programs: canvas.v1

A standalone function can opt into a window by setting entry metadata
`floppy_window: canvas.v1`. The source still has no imports or runtime modules.
The drive opens the trusted `chicago.floppy:program` host and calls your function
with `{event, state}`. `state` is the previous response's plain serializable
`state`, or nil initially. Each window has its own state.

Events include `init`, `tick` (80 ms while active), `key` and `activate`.
Button actions are `pause` and `restart`. Return:

```lua
return {
    state = {score = 0},
    canvas = {
        width = 384, height = 256,
        rects = {{x = 10, y = 10, w = 8, h = 12, color = "#008080"}},
    },
    active = true,
    status = "Left / Right to steer",
    score = "0 m", lives = 3, best = 0,
}
```

The canvas has a white background. At most 1,024 integer rectangle commands are
accepted; dimensions and coordinates are bounded by the host. Use hex RGB colors.
Inactive frames stop ticking and show Start / Resume and New Run buttons.
Optional `can_resume = false` disables Start / Resume after a game ends. Active
frames use keyboard controls without focusable buttons intercepting game keys.
Calls must finish promptly, as with ordinary disk functions. Invalid frames
show an error in the game window.

See `examples/ski.lua` and `tools/ski.go` for the complete bundled game and builder.
The host tracks windows per mount. Eject requests their closure and waits for
confirmation before deleting registry entries. The game never restarts the
computer or installs itself permanently on C:.
