//! D-Bus interface implementation for the FileChooser portal.

use std::collections::HashMap;
use std::sync::mpsc;
use std::sync::Arc;
use std::time::Duration;

use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};

use super::{Pending, Shared};

pub(crate) struct Chooser {
    pub(crate) shared: Arc<Shared>,
}

fn opt_bool(options: &HashMap<String, OwnedValue>, key: &str) -> bool {
    options
        .get(key)
        .and_then(|v| v.downcast_ref::<bool>().ok())
        .unwrap_or(false)
}

fn opt_str(options: &HashMap<String, OwnedValue>, key: &str) -> String {
    options
        .get(key)
        .and_then(|v| v.downcast_ref::<&str>().ok())
        .map(str::to_owned)
        .unwrap_or_default()
}

fn opt_path(options: &HashMap<String, OwnedValue>, key: &str) -> String {
    options
        .get(key)
        .and_then(|v| Vec::<u8>::try_from(v.clone()).ok())
        .map(|mut bytes| {
            while bytes.last() == Some(&0) {
                bytes.pop();
            }
            String::from_utf8_lossy(&bytes).into_owned()
        })
        .unwrap_or_default()
}

impl Chooser {
    fn choose(
        &self,
        handle: String,
        options: HashMap<String, OwnedValue>,
        save: bool,
    ) -> (u32, HashMap<String, OwnedValue>) {
        let directory = opt_bool(&options, "directory");
        let multiple = opt_bool(&options, "multiple");
        let mut current_name = opt_str(&options, "current_name");
        let mut current_folder = opt_path(&options, "current_folder");
        if save && current_name.is_empty() {
            let current_file = opt_path(&options, "current_file");
            if !current_file.is_empty() {
                let p = std::path::Path::new(&current_file);
                if let Some(name) = p.file_name().and_then(|n| n.to_str()) {
                    current_name = name.to_owned();
                }
                if current_folder.is_empty() {
                    if let Some(dir) = p.parent().and_then(|d| d.to_str()) {
                        current_folder = dir.to_owned();
                    }
                }
            }
        }

        let (tx, rx) = mpsc::channel();
        self.shared
            .waiting
            .lock()
            .unwrap()
            .insert(handle.clone(), tx);
        self.shared.pending.lock().unwrap().push_back(Pending {
            handle: handle.clone(),
            directory,
            multiple,
            save,
            current_name,
            current_folder,
        });

        // Blocks this D-Bus worker until the GUI answers (or times out).
        let result = rx.recv_timeout(Duration::from_secs(300));
        self.shared.waiting.lock().unwrap().remove(&handle);

        match result {
            Ok((code, uris)) => {
                let mut out: HashMap<String, OwnedValue> = HashMap::new();
                if code == 0 {
                    if let Ok(v) = Value::from(uris).try_into() {
                        out.insert("uris".to_owned(), v);
                    }
                }
                (code, out)
            }
            Err(_) => (1, HashMap::new()),
        }
    }
}

#[zbus::interface(name = "org.freedesktop.impl.portal.FileChooser")]
impl Chooser {
    fn open_file(
        &self,
        handle: OwnedObjectPath,
        _app_id: String,
        _parent_window: String,
        _title: String,
        options: HashMap<String, OwnedValue>,
    ) -> (u32, HashMap<String, OwnedValue>) {
        self.choose(handle.to_string(), options, false)
    }

    fn save_file(
        &self,
        handle: OwnedObjectPath,
        _app_id: String,
        _parent_window: String,
        _title: String,
        options: HashMap<String, OwnedValue>,
    ) -> (u32, HashMap<String, OwnedValue>) {
        self.choose(handle.to_string(), options, true)
    }

    fn save_files(
        &self,
        handle: OwnedObjectPath,
        _app_id: String,
        _parent_window: String,
        _title: String,
        options: HashMap<String, OwnedValue>,
    ) -> (u32, HashMap<String, OwnedValue>) {
        self.choose(handle.to_string(), options, false)
    }
}
