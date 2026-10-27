# Voxel

A beautiful, customizable file manager, written in Rust and QML.

This project is made to work with [Sleex](https://github.com/axos-project/sleex), but it can be used on any Linux distribution with Qt 6 and Rust installed, as long as the necessary dependencies are available.

## Features

- **Grid & List views** with image thumbnails and sorting (Name, Date, Size, Type)
- **Preview panel & Quick Look** (`Space`) for images, video, audio, and text files
- **Removable drives** support via UDisks2 (mount / unmount from the sidebar)
- **Trash management** following the FreeDesktop Trash specification with undo support
- **XDG Desktop Portal** `FileChooser` backend (`--portal`)
- **Drag-and-drop**, rubber-band selection, and full keyboard navigation

## Building

### Dependencies

- Rust & Cargo
- Qt 6 (`qt6-base`, `qt6-declarative`, `qt6-multimedia`, `qt6-svg`)
- `sleex-ui-kit`

### Compile & Run

```sh
cargo run --release
```

### Arch / AxOS Package

```sh
makepkg -si
```

## Configuration

User preferences are saved automatically to `~/.config/voxel/voxel.conf`:

```toml
sort_by = "Name"
list_type = "grid"
```

## License

Licensed under the [GNU General Public License v3.0](LICENSE).
