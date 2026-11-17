//! Background file operation runner with byte/item progress tracking and cancellation.

use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use crate::fs_ops::remove_path;
use crate::util::path::{split_name, unique_name, valid_name};
use crate::util::text::esc;

static NEXT_ID: AtomicU64 = AtomicU64::new(1);
static TASKS: OnceLock<Mutex<Vec<Arc<Task>>>> = OnceLock::new();

fn tasks_store() -> &'static Mutex<Vec<Arc<Task>>> {
    TASKS.get_or_init(|| Mutex::new(Vec::new()))
}

pub struct Task {
    pub id: u64,
    pub kind: String,
    pub title: String,
    pub current_file: Mutex<String>,
    pub done_bytes: AtomicU64,
    pub total_bytes: AtomicU64,
    pub done_items: AtomicU64,
    pub total_items: AtomicU64,
    pub cancelled: AtomicBool,
    pub finished: AtomicBool,
    pub error: Mutex<Option<String>>,
    pub toast: Mutex<String>,
    pub undo_names: Mutex<String>,
    pub source_paths: Mutex<String>,
}

impl Task {
    fn new(kind: &str, title: String, toast: String) -> Arc<Self> {
        let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        Arc::new(Self {
            id,
            kind: kind.to_owned(),
            title,
            current_file: Mutex::new(String::new()),
            done_bytes: AtomicU64::new(0),
            total_bytes: AtomicU64::new(0),
            done_items: AtomicU64::new(0),
            total_items: AtomicU64::new(0),
            cancelled: AtomicBool::new(false),
            finished: AtomicBool::new(false),
            error: Mutex::new(None),
            toast: Mutex::new(toast),
            undo_names: Mutex::new(String::new()),
            source_paths: Mutex::new(String::new()),
        })
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Relaxed)
    }

    fn set_current(&self, name: &str) {
        if let Ok(mut cur) = self.current_file.lock() {
            *cur = name.to_owned();
        }
    }

    fn set_current_path(&self, path: &Path) {
        if let Some(name) = path.file_name() {
            self.set_current(&name.to_string_lossy());
        }
    }

    fn finish_ok(&self) {
        self.finished.store(true, Ordering::Release);
    }

    fn finish_err(&self, err: String) {
        if err == "Cancelled" {
            self.cancelled.store(true, Ordering::Relaxed);
        } else if let Ok(mut e) = self.error.lock() {
            *e = Some(err);
        }
        self.finished.store(true, Ordering::Release);
    }
}

fn register_task(task: Arc<Task>) {
    if let Ok(mut list) = tasks_store().lock() {
        list.push(task);
    }
}

/// Request cancellation of a running task by ID.
pub fn cancel(id: u64) {
    if let Ok(list) = tasks_store().lock() {
        for t in list.iter() {
            if t.id == id {
                t.cancelled.store(true, Ordering::Relaxed);
            }
        }
    }
}

/// Poll active and newly completed tasks as a JSON string:
/// `{"active":[...],"completed":[...]}`.
pub fn poll_json() -> String {
    let mut active_json = String::new();
    let mut completed_json = String::new();

    if let Ok(mut list) = tasks_store().lock() {
        let mut i = 0;
        while i < list.len() {
            let t = &list[i];
            if t.finished.load(Ordering::Acquire) {
                let t = list.remove(i);
                if !completed_json.is_empty() {
                    completed_json.push(',');
                }
                let err = t
                    .error
                    .lock()
                    .ok()
                    .and_then(|e| e.clone())
                    .unwrap_or_default();
                let toast = t.toast.lock().map(|s| s.clone()).unwrap_or_default();
                let undo = t.undo_names.lock().map(|s| s.clone()).unwrap_or_default();
                let srcs = t.source_paths.lock().map(|s| s.clone()).unwrap_or_default();
                completed_json.push_str(&format!(
                    "{{\"id\":{},\"kind\":\"{}\",\"title\":\"{}\",\"cancelled\":{},\"error\":\"{}\",\"toast\":\"{}\",\"undoNames\":\"{}\",\"sourcePaths\":\"{}\"}}",
                    t.id,
                    esc(&t.kind),
                    esc(&t.title),
                    t.is_cancelled(),
                    esc(&err),
                    esc(&toast),
                    esc(&undo),
                    esc(&srcs),
                ));
            } else {
                if !active_json.is_empty() {
                    active_json.push(',');
                }
                let cur = t.current_file.lock().map(|s| s.clone()).unwrap_or_default();
                let done_b = t.done_bytes.load(Ordering::Relaxed);
                let total_b = t.total_bytes.load(Ordering::Relaxed);
                let done_i = t.done_items.load(Ordering::Relaxed);
                let total_i = t.total_items.load(Ordering::Relaxed);
                let progress = if total_b > 0 {
                    (done_b as f64 / total_b as f64).clamp(0.0, 1.0)
                } else if total_i > 0 {
                    (done_i as f64 / total_i as f64).clamp(0.0, 1.0)
                } else {
                    0.0
                };
                let percent = (progress * 100.0).round() as u32;
                active_json.push_str(&format!(
                    "{{\"id\":{},\"kind\":\"{}\",\"title\":\"{}\",\"currentFile\":\"{}\",\"doneBytes\":{},\"totalBytes\":{},\"doneItems\":{},\"totalItems\":{},\"progress\":{:.4},\"percent\":{},\"cancelled\":{}}}",
                    t.id,
                    esc(&t.kind),
                    esc(&t.title),
                    esc(&cur),
                    done_b,
                    total_b,
                    done_i,
                    total_i,
                    progress,
                    percent,
                    t.is_cancelled(),
                ));
                i += 1;
            }
        }
    }

    format!(
        "{{\"active\":[{}],\"completed\":[{}]}}",
        active_json, completed_json
    )
}

fn file_label(path: &Path) -> String {
    path.file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.to_string_lossy().into_owned())
}

/// Recursively compute `(total_bytes, total_items)` for a slice of paths.
fn scan_paths(paths: &[PathBuf], cancelled: &AtomicBool) -> (u64, u64) {
    let mut bytes = 0u64;
    let mut items = 0u64;
    for p in paths {
        if cancelled.load(Ordering::Relaxed) {
            break;
        }
        let (b, c) = scan_single(p, cancelled);
        bytes = bytes.saturating_add(b);
        items = items.saturating_add(c);
    }
    (bytes, items)
}

fn scan_single(path: &Path, cancelled: &AtomicBool) -> (u64, u64) {
    if cancelled.load(Ordering::Relaxed) {
        return (0, 0);
    }
    let meta = match fs::symlink_metadata(path) {
        Ok(m) => m,
        Err(_) => return (0, 1),
    };
    if meta.file_type().is_symlink() {
        (meta.len(), 1)
    } else if meta.is_dir() {
        let mut bytes = 0u64;
        let mut items = 1u64;
        if let Ok(rd) = fs::read_dir(path) {
            for entry in rd.flatten() {
                if cancelled.load(Ordering::Relaxed) {
                    break;
                }
                let (b, c) = scan_single(&entry.path(), cancelled);
                bytes = bytes.saturating_add(b);
                items = items.saturating_add(c);
            }
        }
        (bytes, items)
    } else {
        (meta.len(), 1)
    }
}

/// Copy `src` to `dst` recursively while updating `task` progress and checking cancellation.
fn copy_recursive_progress(src: &Path, dst: &Path, task: &Task) -> Result<(), String> {
    if task.is_cancelled() {
        return Err("Cancelled".to_owned());
    }
    task.set_current_path(src);
    let meta = fs::symlink_metadata(src).map_err(|e| e.to_string())?;
    if meta.file_type().is_symlink() {
        let target = fs::read_link(src).map_err(|e| e.to_string())?;
        std::os::unix::fs::symlink(target, dst).map_err(|e| e.to_string())?;
        task.done_bytes.fetch_add(meta.len(), Ordering::Relaxed);
        task.done_items.fetch_add(1, Ordering::Relaxed);
        Ok(())
    } else if meta.is_dir() {
        fs::create_dir_all(dst).map_err(|e| e.to_string())?;
        task.done_items.fetch_add(1, Ordering::Relaxed);
        for item in fs::read_dir(src).map_err(|e| e.to_string())? {
            if task.is_cancelled() {
                return Err("Cancelled".to_owned());
            }
            let item = item.map_err(|e| e.to_string())?;
            copy_recursive_progress(&item.path(), &dst.join(item.file_name()), task)?;
        }
        Ok(())
    } else {
        copy_file_chunked(src, dst, &meta, task)
    }
}

fn copy_file_chunked(
    src: &Path,
    dst: &Path,
    meta: &fs::Metadata,
    task: &Task,
) -> Result<(), String> {
    let mut reader = fs::File::open(src).map_err(|e| e.to_string())?;
    let mut writer = fs::File::create(dst).map_err(|e| e.to_string())?;
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        if task.is_cancelled() {
            drop(writer);
            let _ = fs::remove_file(dst);
            return Err("Cancelled".to_owned());
        }
        let n = reader.read(&mut buf).map_err(|e| {
            let _ = fs::remove_file(dst);
            e.to_string()
        })?;
        if n == 0 {
            break;
        }
        writer.write_all(&buf[..n]).map_err(|e| {
            let _ = fs::remove_file(dst);
            e.to_string()
        })?;
        task.done_bytes.fetch_add(n as u64, Ordering::Relaxed);
    }
    let _ = fs::set_permissions(dst, meta.permissions());
    task.done_items.fetch_add(1, Ordering::Relaxed);
    Ok(())
}

fn copy_into_progress(dest_dir: &Path, src: &Path, task: &Task) -> Result<PathBuf, String> {
    let name = src
        .file_name()
        .ok_or_else(|| "Invalid source".to_owned())?
        .to_string_lossy()
        .into_owned();
    let (base, ext) = split_name(&name);
    let dst = dest_dir.join(unique_name(dest_dir, &base, &ext));
    copy_recursive_progress(src, &dst, task)?;
    Ok(dst)
}

fn move_entry_progress(dest_dir: &Path, src: &Path, task: &Task) -> Result<(), String> {
    if task.is_cancelled() {
        return Err("Cancelled".to_owned());
    }
    task.set_current_path(src);
    let (entry_bytes, entry_items) = scan_single(src, &task.cancelled);
    if src.parent() == Some(dest_dir) {
        task.done_bytes.fetch_add(entry_bytes, Ordering::Relaxed);
        task.done_items.fetch_add(entry_items, Ordering::Relaxed);
        return Ok(());
    }
    let canonical_src = fs::canonicalize(src).unwrap_or_else(|_| src.to_path_buf());
    let canonical_dest = fs::canonicalize(dest_dir).unwrap_or_else(|_| dest_dir.to_path_buf());
    if canonical_dest == canonical_src {
        task.done_bytes.fetch_add(entry_bytes, Ordering::Relaxed);
        task.done_items.fetch_add(entry_items, Ordering::Relaxed);
        return Ok(());
    }
    if canonical_dest.starts_with(&canonical_src) {
        return Err(format!(
            "Cannot move \u{201c}{}\u{201d} into itself",
            src.display()
        ));
    }
    let name = src
        .file_name()
        .ok_or_else(|| "Invalid source".to_owned())?
        .to_string_lossy()
        .into_owned();
    let (base, ext) = split_name(&name);
    let dst = dest_dir.join(unique_name(dest_dir, &base, &ext));
    if fs::rename(src, &dst).is_ok() {
        task.done_bytes.fetch_add(entry_bytes, Ordering::Relaxed);
        task.done_items.fetch_add(entry_items, Ordering::Relaxed);
        return Ok(());
    }
    if let Err(e) = copy_recursive_progress(src, &dst, task) {
        remove_path(&dst);
        return Err(e);
    }
    remove_path(src);
    Ok(())
}

fn delete_recursive_progress(path: &Path, task: &Task) -> Result<(), String> {
    if task.is_cancelled() {
        return Err("Cancelled".to_owned());
    }
    task.set_current_path(path);
    let meta = fs::symlink_metadata(path).map_err(|e| e.to_string())?;
    let is_link = meta.file_type().is_symlink();
    if !is_link && meta.is_dir() {
        for item in fs::read_dir(path).map_err(|e| e.to_string())? {
            if task.is_cancelled() {
                return Err("Cancelled".to_owned());
            }
            let item = item.map_err(|e| e.to_string())?;
            delete_recursive_progress(&item.path(), task)?;
        }
        fs::remove_dir(path).map_err(|e| e.to_string())?;
        task.done_items.fetch_add(1, Ordering::Relaxed);
        Ok(())
    } else {
        let len = meta.len();
        fs::remove_file(path).map_err(|e| e.to_string())?;
        task.done_bytes.fetch_add(len, Ordering::Relaxed);
        task.done_items.fetch_add(1, Ordering::Relaxed);
        Ok(())
    }
}

/// Start a background Copy operation into `dest_dir`. Returns the task ID.
pub fn start_copy(dest_dir: PathBuf, paths: Vec<PathBuf>, custom_toast: Option<String>) -> u64 {
    let n = paths.len();
    let title = if n == 1 {
        format!("Copying {}", file_label(&paths[0]))
    } else {
        format!("Copying {} items", n)
    };
    let toast = custom_toast.unwrap_or_else(|| {
        if n == 1 {
            "Copied".to_owned()
        } else {
            format!("Copied {} items", n)
        }
    });
    let task = Task::new("copy", title, toast);
    let id = task.id;
    register_task(task.clone());

    std::thread::spawn(move || {
        if !dest_dir.is_dir() {
            task.finish_err("Not a directory".to_owned());
            return;
        }
        let (total_b, total_i) = scan_paths(&paths, &task.cancelled);
        task.total_bytes.store(total_b, Ordering::Relaxed);
        task.total_items.store(total_i.max(1), Ordering::Relaxed);

        for src in &paths {
            if let Err(e) = copy_into_progress(&dest_dir, src, &task) {
                task.finish_err(e);
                return;
            }
        }
        task.finish_ok();
    });

    id
}

/// Start a background Move operation into `dest_dir`. Returns the task ID.
pub fn start_move(dest_dir: PathBuf, paths: Vec<PathBuf>) -> u64 {
    let n = paths.len();
    let title = if n == 1 {
        format!("Moving {}", file_label(&paths[0]))
    } else {
        format!("Moving {} items", n)
    };
    let toast = if n == 1 {
        "Moved".to_owned()
    } else {
        format!("Moved {} items", n)
    };
    let task = Task::new("move", title, toast);
    let id = task.id;
    register_task(task.clone());

    std::thread::spawn(move || {
        if !dest_dir.is_dir() {
            task.finish_err("Not a directory".to_owned());
            return;
        }
        let (total_b, total_i) = scan_paths(&paths, &task.cancelled);
        task.total_bytes.store(total_b, Ordering::Relaxed);
        task.total_items.store(total_i.max(1), Ordering::Relaxed);

        for src in &paths {
            if let Err(e) = move_entry_progress(&dest_dir, src, &task) {
                task.finish_err(e);
                return;
            }
        }
        task.finish_ok();
    });

    id
}

/// Start a background permanent Delete operation. Returns the task ID.
pub fn start_delete(paths: Vec<PathBuf>) -> u64 {
    let n = paths.len();
    let title = if n == 1 {
        format!("Deleting {}", file_label(&paths[0]))
    } else {
        format!("Deleting {} items", n)
    };
    let toast = if n == 1 {
        "Deleted".to_owned()
    } else {
        format!("Deleted {} items", n)
    };
    let task = Task::new("delete", title, toast);
    let id = task.id;
    register_task(task.clone());

    std::thread::spawn(move || {
        let (total_b, total_i) = scan_paths(&paths, &task.cancelled);
        task.total_bytes.store(total_b, Ordering::Relaxed);
        task.total_items.store(total_i.max(1), Ordering::Relaxed);

        for p in &paths {
            if let Err(e) = delete_recursive_progress(p, &task) {
                task.finish_err(e);
                return;
            }
        }
        task.finish_ok();
    });

    id
}

/// Start a background Move-to-Trash operation. Returns the task ID.
pub fn start_trash(paths: Vec<PathBuf>) -> u64 {
    let n = paths.len();
    let title = if n == 1 {
        format!("Trashing {}", file_label(&paths[0]))
    } else {
        format!("Trashing {} items", n)
    };
    let toast = if n == 1 {
        "Trashed".to_owned()
    } else {
        format!("Trashed {} items", n)
    };
    let task = Task::new("trash", title, toast);
    if let Ok(mut sp) = task.source_paths.lock() {
        *sp = paths
            .iter()
            .map(|p| p.to_string_lossy().into_owned())
            .collect::<Vec<_>>()
            .join("\n");
    }
    let id = task.id;
    register_task(task.clone());

    std::thread::spawn(move || {
        task.total_items.store(paths.len().max(1) as u64, Ordering::Relaxed);
        if let Some(first) = paths.first() {
            task.set_current_path(first);
        }
        match crate::trash::trash_paths(&paths) {
            Ok(names) => {
                task.done_items.store(paths.len() as u64, Ordering::Relaxed);
                if let Ok(mut u) = task.undo_names.lock() {
                    *u = names.join("\n");
                }
                task.finish_ok();
            }
            Err(e) => {
                task.finish_err(e);
            }
        }
    });

    id
}

/// Start a background Restore-from-Trash operation. Returns the task ID.
pub fn start_restore(names: Vec<String>) -> u64 {
    let n = names.len();
    let title = if n == 1 {
        format!("Restoring {}", names[0])
    } else {
        format!("Restoring {} items", n)
    };
    let task = Task::new("restore", title, "Restored".to_owned());
    let id = task.id;
    register_task(task.clone());

    std::thread::spawn(move || {
        task.total_items.store(names.len().max(1) as u64, Ordering::Relaxed);
        if let Some(first) = names.first() {
            task.set_current(first);
        }
        match crate::trash::restore(&names) {
            Ok(()) => {
                task.done_items.store(names.len() as u64, Ordering::Relaxed);
                task.finish_ok();
            }
            Err(e) => {
                task.finish_err(e);
            }
        }
    });

    id
}

/// Start a background Empty-Trash operation. Returns the task ID.
pub fn start_empty_trash() -> u64 {
    let task = Task::new("empty_trash", "Emptying Trash".to_owned(), "Trash emptied".to_owned());
    let id = task.id;
    register_task(task.clone());

    std::thread::spawn(move || {
        let root = crate::trash::root();
        let files = root.join("files");
        let info = root.join("info");
        let entries: Vec<PathBuf> = fs::read_dir(&files)
            .into_iter()
            .flatten()
            .flatten()
            .map(|e| e.path())
            .collect();
        let (total_b, total_i) = scan_paths(&entries, &task.cancelled);
        task.total_bytes.store(total_b, Ordering::Relaxed);
        task.total_items.store(total_i.max(1), Ordering::Relaxed);

        for p in &entries {
            if task.is_cancelled() {
                task.finish_err("Cancelled".to_owned());
                return;
            }
            let _ = delete_recursive_progress(p, &task);
            if let Some(fname) = p.file_name() {
                let info_file = info.join(format!("{}.trashinfo", fname.to_string_lossy()));
                let _ = fs::remove_file(info_file);
            }
        }
        // Clean up any remaining orphan .trashinfo files
        for item in fs::read_dir(&info).into_iter().flatten().flatten() {
            let _ = fs::remove_file(item.path());
        }
        let _ = valid_name("");
        task.finish_ok();
    });

    id
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    fn wait_for_task(id: u64) -> serde_json::Value {
        let start = Instant::now();
        loop {
            let json = poll_json();
            let val: serde_json::Value = serde_json::from_str(&json).unwrap();
            if let Some(completed) = val["completed"].as_array() {
                for item in completed {
                    if item["id"].as_u64() == Some(id) {
                        return item.clone();
                    }
                }
            }
            assert!(
                start.elapsed() < Duration::from_secs(5),
                "Task {id} timed out"
            );
            std::thread::sleep(Duration::from_millis(10));
        }
    }

    #[test]
    fn copy_move_and_delete_progress_lifecycle() {
        let base = std::env::temp_dir().join(format!("voxel_task_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&base);
        let src_dir = base.join("src");
        let dst_dir = base.join("dst");
        let move_dir = base.join("moved");
        fs::create_dir_all(&src_dir).unwrap();
        fs::create_dir_all(&dst_dir).unwrap();
        fs::create_dir_all(&move_dir).unwrap();

        let file_a = src_dir.join("hello.txt");
        fs::write(&file_a, vec![b'x'; 128 * 1024]).unwrap();

        // 1. Copy
        let copy_id = start_copy(dst_dir.clone(), vec![file_a.clone()], Some("Pasted".into()));
        let copy_done = wait_for_task(copy_id);
        assert_eq!(copy_done["cancelled"], false);
        assert_eq!(copy_done["error"], "");
        assert_eq!(copy_done["toast"], "Pasted");
        assert!(dst_dir.join("hello.txt").exists());
        assert_eq!(
            fs::metadata(dst_dir.join("hello.txt")).unwrap().len(),
            128 * 1024
        );

        // 2. Move
        let move_id = start_move(move_dir.clone(), vec![dst_dir.join("hello.txt")]);
        let move_done = wait_for_task(move_id);
        assert_eq!(move_done["cancelled"], false);
        assert_eq!(move_done["error"], "");
        assert!(!dst_dir.join("hello.txt").exists());
        assert!(move_dir.join("hello.txt").exists());

        // 3. Delete
        let del_id = start_delete(vec![move_dir.join("hello.txt")]);
        let del_done = wait_for_task(del_id);
        assert_eq!(del_done["cancelled"], false);
        assert_eq!(del_done["error"], "");
        assert!(!move_dir.join("hello.txt").exists());

        let _ = fs::remove_dir_all(&base);
    }
}
