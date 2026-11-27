//! Clipboard operations exposed to QML.

use std::path::PathBuf;

use qmetaobject::prelude::*;

use crate::clipboard;

#[derive(QObject, Default)]
pub struct Clipboard {
    base: qt_base_class!(trait QObject),

    // Copy paths (newline separated) to the clipboard as a file list and
    // remember them for in-app Paste. Returns "".
    copy_to_clipboard: qt_method!(
        fn copy_to_clipboard(&self, paths: QString) -> QString {
            let list: Vec<PathBuf> = crate::util::path::parse_paths(&paths.to_string());
            clipboard::set_files(list);
            QString::from("")
        }
    ),

    // Cut paths (newline separated) to the clipboard so Paste moves them.
    cut_to_clipboard: qt_method!(
        fn cut_to_clipboard(&self, paths: QString) -> QString {
            let list: Vec<PathBuf> = crate::util::path::parse_paths(&paths.to_string());
            clipboard::cut_files(list);
            QString::from("")
        }
    ),

    // Put arbitrary text (e.g. a path) on the clipboard as plain text.
    copy_text: qt_method!(
        fn copy_text(&self, text: QString) -> QString {
            clipboard::set_text(&text.to_string());
            QString::from("")
        }
    ),

    // Number of paths currently held in the in-app clipboard.
    clipboard_count: qt_method!(
        fn clipboard_count(&self) -> i32 {
            clipboard::count() as i32
        }
    ),

    // Whether the current clipboard holds cut (move) items.
    clipboard_is_cut: qt_method!(
        fn clipboard_is_cut(&self) -> bool {
            clipboard::is_cut()
        }
    ),

    // Newline-separated paths currently held in the in-app clipboard.
    clipboard_paths: qt_method!(
        fn clipboard_paths(&self) -> QString {
            let paths = clipboard::get_paths();
            let joined = paths
                .iter()
                .map(|p| p.to_string_lossy().into_owned())
                .collect::<Vec<_>>()
                .join("\n");
            joined.into()
        }
    ),

    // Clear the in-app clipboard.
    clear_clipboard: qt_method!(
        fn clear_clipboard(&self) {
            clipboard::clear();
        }
    ),

    // Copy the clipboard contents into `dest`, avoiding name collisions.
    // Returns "" on success or an error message.
    paste: qt_method!(
        fn paste(&self, dest: QString) -> QString {
            let dest = PathBuf::from(dest.to_string());
            if !dest.is_dir() {
                return QString::from("Not a directory");
            }
            match clipboard::paste_into(&dest) {
                Ok(_) => QString::from(""),
                Err(e) => e.into(),
            }
        }
    ),

    // Whether the system clipboard currently holds a raw image (e.g. a screenshot).
    clipboard_has_image: qt_method!(
        fn clipboard_has_image(&self) -> bool {
            clipboard::has_image()
        }
    ),

    // Paste an image from the system clipboard into `dest`.
    // Returns the created file path on success, or "error:<msg>" on failure.
    paste_image: qt_method!(
        fn paste_image(&self, dest: QString) -> QString {
            let dest = PathBuf::from(dest.to_string());
            match clipboard::paste_image_into(&dest) {
                Ok(path) => path.to_string_lossy().into_owned().into(),
                Err(e) => format!("error:{e}").into(),
            }
        }
    ),
}
