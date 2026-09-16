# chicago/floppy

An executable virtual floppy prototype, exposed as A: through the shell's
`chicago.drive` registry contract. Requires shell v0.3.4 or newer and the runtime
with `hub.open(fs, path)` and `registry.overlay(owner)`.

## Try it

Install the published module in the Chicago application and restart the desktop.
Open My Computer, then 3½ Floppy (A:) under an administrator account.
The filename starts as `ski.wapp`. Press **Insert → Setup…**.

The Wippy Setup Wizard follows the classic installation ceremony:

1. Welcome, with a teal illustrated sidebar and Back / Next / Cancel buttons.
2. Destination folder, initially `C:\PROGRAM FILES\WIPPY\`.
3. Simulated file copying, with source and destination filenames and a progress bar.
   It reaches 99% in eight seconds and stays there for ten seconds while displaying
   “Updating system configuration…”. The window remains responsive to Cancel.
4. Real temporary registration of the WAPP functions. Success is shown only after
   registration succeeds; errors show Retry and Cancel.
5. Setup Complete, with the classic restart choices. “No, I will restart my
   computer later” is selected; Restart now is disabled. Finish returns to the
   drive without restarting the computer, desktop or any running applications.

Select **Ski** and click **Run** to open the game.
**Eject** closes its game windows and removes its temporary programs. Other disks
can be placed in `disks/` and selected by basename. The older `hello.wapp` is
still included as a minimal authoring example.

The copy animation and destination are nostalgic presentation: Setup writes no
files to C:, and its filenames illustrate installation rather than enumerate
archive contents. Registration is real, but remains tied to the inserted disk.
Cancel before completion leaves the disk inserted and its programs unregistered.
Closing the drive cleans up the package and its entries as usual.

## Ski: Downhill Adventures

The bundled `ski.wapp` is a small original game inspired by SkiFree. It contains
its own game logic and pixel art; it is not a shortcut to a built-in game.

- Space starts, pauses and resumes; Left / Right steer; R starts a new run.
- Avoid trees and rocks. Three falls end a run.
- Distance and the best run in the current window are shown above the slope.
- Ejecting the disk closes its game windows before removing the program.
- Pixel graphics are required for the slope; the cell UI shows an explanation.

Source: `examples/ski.lua`. Rebuild the disk with `make ski`. No runtime changes
are required. The canvas host accepts a fixed 384×256 frame and at most 1,024
validated rectangle commands; it does not grant imports or modules to disk code.
The wizard's original illustration is `assets/images/setup.svg`; regenerate its
PNG with `python3 tools/setup_art.py` (Pillow).

## Lifecycle

- Insert opens the package without registering or running its entries. Resource
  metadata and an optional README.txt preview are read through the package FS.
- Setup validates all entries before starting its animation, then registers them
  in an owned registry overlay after the 99% pause.
  Every drive window gets a random owner and namespace. Package entry names are
  remapped into it, preventing collisions between two copies of the same disk.
- Run calls a plain function or opens a canvas program in the module's generic
  window host. Canvas state and pixels come from the disk's function.
- Eject first closes this mount's canvas windows, waits until they stop,
  deletes only the entries owned by this overlay, then closes the package.
  A failed cleanup keeps the disk attached and reports the reason.
- Normal window close performs the same cleanup. A forced process kill can
  leave overlay entries until the runtime restarts; forced-death reconciliation
  and a desktop-wide mount controller are not implemented in this prototype.

## Supported packages

The first executable contract accepts up to 32 standalone `function.lua`
entries, each containing only packed `source` and `method` data. The optional
metadata title is shown in the program list. Imports, runtime modules, services,
migrations, library linking, arbitrary process entries and permanent installation are not
supported yet and fail before registration. Files up to 8 MB are accepted;
README preview is limited to 16 KB. Only administrators can open the drive.
Package FS resources are available to the drive browser; they are not installed
into the global FS registry or injected into standalone functions.

This is temporary execution from a disk. An installed application's package
would need independent storage and persistence so eject would not unload it.

## Development

```
make demo
make ski
make test WIPPY=/path/to/runtime/with/local-wapp-support
make lint WIPPY=/path/to/runtime/with/local-wapp-support
```

The harness replaces only Floppy. Shell and tui-desktop are installed from
published tags, so layout tests exercise the SDK version users receive.

The standalone harness verifies the full timed wizard through button clicks in a real
window process, reading resources, execution, per-mount isolation, cleanup,
unsupported-entry refusal and error recovery. It renders `test/shots/floppy.png`.
Wizard screenshots are saved as `test/shots/setup_*.png` at two pixel cell sizes.
The application's `bin/wippy-floppy` is a separately built development binary;
its standard `bin/wippy` is unchanged.

## Authoring disks with agents

See [Creating WAPP floppy disks](src/docs/authoring.md) for the supported format,
a complete builder example and verification steps. The same guide is available
in the registry as `chicago.floppy:definition` → `readme`.

The module also contributes four `chicago.tip` entries. Welcome discovers them
automatically and its Show Me button opens the drive.
