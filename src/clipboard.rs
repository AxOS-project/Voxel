use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Mutex;

use crate::fs_ops::copy_into;
use crate::util::text::file_uri;

/// Paths copied or cut in-app, kept so Paste works without a system clipboard helper.
struct ClipData {
    paths: Vec<PathBuf>,
    cut: bool,
}

static CLIPBOARD: Mutex<ClipData> = Mutex::new(ClipData {
    paths: Vec::new(),
    cut: false,
});

/// Feed `data` to a clipboard helper over stdin; true when it exits cleanly.
fn pipe_to(cmd: &str, args: &[&str], data: &str) -> bool {
    let child = Command::new(cmd)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
    let mut child = match child {
        Ok(c) => c,
        Err(_) => return false,
    };
    if let Some(mut si) = child.stdin.take() {
        if si.write_all(data.as_bytes()).is_err() {
            return false;
        }
    }
    child.wait().map(|s| s.success()).unwrap_or(false)
}

/// Publish `data` under `mime` on the system clipboard, trying wl-copy then
/// the classic X11 helpers. Returns false when no helper is available.
pub fn write(mime: &str, data: &str) -> bool {
    let wayland = std::env::var_os("WAYLAND_DISPLAY").is_some();
    let x11 = std::env::var_os("DISPLAY").is_some();
    let mut attempts: Vec<(&str, Vec<&str>)> = Vec::new();
    if wayland {
        attempts.push(("wl-copy", vec!["--type", mime]));
    }
    if x11 {
        attempts.push(("xclip", vec!["-selection", "clipboard", "-t", mime, "-i"]));
    }
    if !wayland {
        attempts.push(("wl-copy", vec!["--type", mime]));
    }
    attempts.push(("xsel", vec!["--clipboard", "--input"]));
    attempts
        .into_iter()
        .any(|(cmd, args)| pipe_to(cmd, &args, data))
}

/// Copy paths to the system clipboard as a `text/uri-list` and remember them
/// for in-app Paste.
pub fn set_files(paths: Vec<PathBuf>) {
    store_files(paths, false);
}

/// Cut paths to the clipboard so the next Paste moves them to the destination.
pub fn cut_files(paths: Vec<PathBuf>) {
    store_files(paths, true);
}

fn store_files(paths: Vec<PathBuf>, cut: bool) {
    if paths.is_empty() {
        return;
    }
    let mut uri_list = String::new();
    for p in &paths {
        uri_list.push_str(&file_uri(&p.to_string_lossy()));
        uri_list.push_str("\r\n");
    }
    write("text/uri-list", &uri_list);
    if let Ok(mut clip) = CLIPBOARD.lock() {
        clip.paths = paths;
        clip.cut = cut;
    }
}

/// Put arbitrary text (e.g. a path) on the system clipboard as plain text.
pub fn set_text(text: &str) {
    write("text/plain", text);
}

/// Number of paths currently held in the in-app clipboard.
pub fn count() -> usize {
    CLIPBOARD.lock().map(|c| c.paths.len()).unwrap_or(0)
}

/// Whether the current in-app clipboard holds cut (move) items.
pub fn is_cut() -> bool {
    CLIPBOARD.lock().map(|c| c.cut && !c.paths.is_empty()).unwrap_or(false)
}

/// Clone the paths currently held in the in-app clipboard.
pub fn get_paths() -> Vec<PathBuf> {
    CLIPBOARD.lock().map(|c| c.paths.clone()).unwrap_or_default()
}

/// Clear the in-app clipboard state (e.g. after completing a cut-paste move).
pub fn clear() {
    if let Ok(mut clip) = CLIPBOARD.lock() {
        clip.paths.clear();
        clip.cut = false;
    }
}

/// Copy the in-app clipboard contents into `dest`, avoiding name collisions.
pub fn paste_into(dest: &Path) -> Result<(), String> {
    let items = get_paths();
    for src in &items {
        copy_into(dest, src)?;
    }
    Ok(())
}
