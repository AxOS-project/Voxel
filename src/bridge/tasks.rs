//! Background file tasks exposed to QML.

use std::path::PathBuf;

use qmetaobject::prelude::*;

use crate::tasks;

#[derive(QObject, Default)]
pub struct Tasks {
    base: qt_base_class!(trait QObject),

    // Poll active and recently completed tasks as JSON: {active:[...], completed:[...]}.
    poll_json: qt_method!(
        fn poll_json(&self) -> QString {
            tasks::poll_json().into()
        }
    ),

    // Cancel a running task by ID.
    cancel: qt_method!(
        fn cancel(&self, id: i32) {
            if id > 0 {
                tasks::cancel(id as u64);
            }
        }
    ),

    // Copy newline-separated local paths into `dest`. Optional custom toast message.
    copy_paths: qt_method!(
        fn copy_paths(&self, dest: QString, paths: QString, toast: QString) -> i32 {
            let dest = PathBuf::from(dest.to_string());
            let list = crate::util::path::parse_paths(&paths.to_string());
            if list.is_empty() {
                return 0;
            }
            let toast_str = toast.to_string();
            let custom_toast = if toast_str.is_empty() { None } else { Some(toast_str) };
            tasks::start_copy(dest, list, custom_toast) as i32
        }
    ),

    // Copy newline-separated `file://` URIs into `dest`.
    copy_uris: qt_method!(
        fn copy_uris(&self, dest: QString, uris: QString) -> i32 {
            let dest = PathBuf::from(dest.to_string());
            let list = uris_to_paths(&uris.to_string());
            if list.is_empty() {
                return 0;
            }
            tasks::start_copy(dest, list, None) as i32
        }
    ),

    // Move newline-separated local paths into `dest`.
    move_paths: qt_method!(
        fn move_paths(&self, dest: QString, paths: QString) -> i32 {
            let dest = PathBuf::from(dest.to_string());
            let list = crate::util::path::parse_paths(&paths.to_string());
            if list.is_empty() {
                return 0;
            }
            tasks::start_move(dest, list) as i32
        }
    ),

    // Move newline-separated `file://` URIs into `dest`.
    move_uris: qt_method!(
        fn move_uris(&self, dest: QString, uris: QString) -> i32 {
            let dest = PathBuf::from(dest.to_string());
            let list = uris_to_paths(&uris.to_string());
            if list.is_empty() {
                return 0;
            }
            tasks::start_move(dest, list) as i32
        }
    ),

    // Permanently delete newline-separated local paths.
    delete_paths: qt_method!(
        fn delete_paths(&self, paths: QString) -> i32 {
            let list = crate::util::path::parse_paths(&paths.to_string());
            if list.is_empty() {
                return 0;
            }
            tasks::start_delete(list) as i32
        }
    ),

    // Move newline-separated local paths to the home trash.
    trash_paths: qt_method!(
        fn trash_paths(&self, paths: QString) -> i32 {
            let list = crate::util::path::parse_paths(&paths.to_string());
            if list.is_empty() {
                return 0;
            }
            tasks::start_trash(list) as i32
        }
    ),

    // Restore entries from trash by their newline-separated stored names.
    restore_trash: qt_method!(
        fn restore_trash(&self, names: QString) -> i32 {
            let list: Vec<String> = names
                .to_string()
                .lines()
                .filter(|s| !s.is_empty())
                .map(str::to_owned)
                .collect();
            if list.is_empty() {
                return 0;
            }
            tasks::start_restore(list) as i32
        }
    ),

    // Empty the home trash in the background.
    empty_trash: qt_method!(
        fn empty_trash(&self) -> i32 {
            tasks::start_empty_trash() as i32
        }
    ),
}

fn uris_to_paths(list: &str) -> Vec<PathBuf> {
    list.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .map(|l| PathBuf::from(crate::util::text::from_uri(l)))
        .collect()
}
