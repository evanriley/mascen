# mascen

A custom layout generator for the [River](https://github.com/riverwm/river) Wayland compositor, implemented in Zig.

## Requirements

- Zig 0.15.2
- Wayland scanner/protocols (if not bundled or handled by build.zig dependencies)

## Build

You can build the project using Zig directly:

```sh
zig build -Doptimize=ReleaseSafe
```

Or use the provided Makefile:

```sh
make
```

The executable will be located at `zig-out/bin/mascen`.

## Installation

To install to `/usr/local/bin` (or `PREFIX` of your choice):

```sh
sudo make install
```

## Usage

Run `mascen` from your River configuration (e.g., `river.init`):

```sh
riverctl layout mascen mascen
mascen &
```

### Configuration

You can configure `mascen` using command-line flags when starting the executable:

| Flag | Description | Default |
|------|-------------|---------|
| `--master-width <float>` | Width ratio of the master column (0.0 - 1.0) | `0.5` |
| `--gap <int>` | Outer gaps in pixels | `10` |
| `--inner-gap <int>` | Inner gaps between windows in pixels | `10` |
| `--smart-gaps <bool>` | Disable gaps when only one window is visible (`true`/`false`) | `false` |

Example:
```sh
mascen --master-width 0.6 --gap 5 --inner-gap 5 --smart-gaps true &
```

### Runtime Commands

You can also change settings at runtime using `riverctl send-layout-cmd`:

```sh
riverctl send-layout-cmd mascen "master-width 0.7"
riverctl send-layout-cmd mascen "gap 15"
riverctl send-layout-cmd mascen "inner-gap 15"
riverctl send-layout-cmd mascen "smart-gaps true"
```
