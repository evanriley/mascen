# mascen

Mastered Centered layout generator for River.
Think Master layout with the orientation setting equal to 'center' in hyprland.

### In this layout

- The Master window (the last one in the list) takes the center.
- The Stack windows alternate between the Right and Left columns.

```text
+-------------+---------------------------+-------------+
|             |                           |             |
|   Stack 1   |                           |   Stack 0   |
|             |                           |             |
+-------------+          Master           +-------------+
|             |                           |             |
|   Stack 3   |                           |   Stack 2   |
|             |                           |             |
+-------------+---------------------------+-------------+
```


This is very much 'alpha' quality.

If it works for you, wonderful!

If it doesn't I will accept a pull request but support is extremely limited.

I will most likely ignore feature request and will close those issues without warning or repsonse.

## Requirements

- Zig 0.15.2

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

Run `mascen` from your River configuration (e.g., `init`):

```sh
mascen --master-width 0.5 --gap 20 --inner-gap 10 --smart-gaps true &
riverctl default-layout mascen
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
