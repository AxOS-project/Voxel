//! QML bridge: thin QObject wrappers exposing the backend to Qt Quick.

mod clipboard;
mod fs;
mod portal;
mod preview;
mod trash;
mod udisk;

use cstr::cstr;
use qmetaobject::qml_register_type;

/// Register every bridge type in the `Voxel` QML module.
pub fn register() {
    qml_register_type::<fs::Fs>(cstr!("Voxel"), 1, 0, cstr!("Fs"));
    qml_register_type::<clipboard::Clipboard>(cstr!("Voxel"), 1, 0, cstr!("Clipboard"));
    qml_register_type::<preview::Preview>(cstr!("Voxel"), 1, 0, cstr!("Preview"));
    qml_register_type::<trash::Trash>(cstr!("Voxel"), 1, 0, cstr!("Trash"));
    qml_register_type::<portal::Portal>(cstr!("Voxel"), 1, 0, cstr!("Portal"));
    qml_register_type::<udisk::Udisk>(cstr!("Voxel"), 1, 0, cstr!("Udisk"));
}
