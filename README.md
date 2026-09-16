# chicago/floppy

An executable virtual floppy prototype, exposed as A: through the shell's
`chicago.drive` registry contract. Requires shell v0.2.5 or newer and the runtime
with `hub.open(fs, path)` and `registry.overlay(owner)`.

## Try it

The Chicago application currently replaces `chicago/floppy` with this checkout.
From the application directory, stop its existing runtime and start:

```
./bin/wippy-floppy run -c
```

Open My Computer, then 3½ Floppy (A:) under an administrator account.
The filename starts as `hello.wapp`. Press Insert, Register, Run, then Eject.
The demo returns a greeting in the drive window. Other disk files can be placed
in `disks/` and selected by basename in the filename field.

## Lifecycle

- Insert opens the package without registering or running its entries. Resource
  metadata and an optional README.txt preview are read through the package FS.
- Register validates all entries before creating an owned registry overlay.
  Every drive window gets a random owner and namespace. Package entry names are
  remapped into it, preventing collisions between two copies of the same disk.
- Run calls the selected temporary function. Calls are synchronous; the disk
  cannot be ejected while a call is in progress. Errors leave it ejectable.
- Eject deletes only the entries owned by this overlay, then closes the package.
  A failed cleanup keeps the disk attached and reports the reason.
- Normal window close performs the same cleanup. A forced process kill can
  leave overlay entries until the runtime restarts; forced-death reconciliation
  and a desktop-wide mount controller are not implemented in this prototype.

## Supported packages

The first executable contract accepts up to 32 standalone `function.lua`
entries, each containing only packed `source` and `method` data. The optional
metadata title is shown in the program list. Imports, runtime modules, services,
migrations, library linking, process windows and permanent installation are not
supported yet and fail before registration. Files up to 8 MB are accepted;
README preview is limited to 16 KB. Only administrators can open the drive.
Package FS resources are available to the drive browser; they are not installed
into the global FS registry or injected into standalone functions.

This is temporary execution from a disk. An installed application's package
would need independent storage and persistence so eject would not unload it.

## Development

```
make demo
make test WIPPY=/path/to/runtime/with/local-wapp-support
make lint WIPPY=/path/to/runtime/with/local-wapp-support
```

The standalone harness verifies Explorer discovery and button clicks in a real
window process, reading resources, execution, per-mount isolation, cleanup,
unsupported-entry refusal and error recovery. It renders `test/shots/floppy.png`.
The application's `bin/wippy-floppy` is a separately built development binary;
its standard `bin/wippy` is unchanged.

## Authoring disks with agents

See [Creating WAPP floppy disks](src/docs/authoring.md) for the supported format,
a complete builder example and verification steps. The same guide is available
in the registry as `chicago.floppy:definition` → `readme`.

The module also contributes four `chicago.tip` entries. Welcome discovers them
automatically and its Show Me button opens the drive.
