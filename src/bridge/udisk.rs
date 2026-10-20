use qmetaobject::prelude::*;
use std::{collections::HashMap};
use zbus::{blocking::fdo::ObjectManagerProxy, blocking::Connection, proxy, Result};

#[derive(QObject, Default)]
pub struct Udisk {
    base: qt_base_class!(trait QObject),

    // List block devices and their mount points
    list_devices: qt_method!(
        fn list_devices(&self) -> QString {
            match self.get_block_devices() {
                Ok(devices) => {
                    let json = serde_json::to_string(&devices).unwrap_or_else(|_| "[]".to_string());
                    QString::from(json)
                }
                Err(e) => format!("error:{}", e).into(),
            }
        }
    ),

    // Mount a block device at the given path
    mount_device: qt_method!(
        fn mount_device(&self, path: QString) -> QString {
            match self.mount_device_on_path(&path.to_string()) {
                Ok(mount_point) => QString::from(mount_point),
                Err(e) => format!("error:{}", e).into(),
            }
        }
    ),

    // Unmount a block device at the given path
    unmount_device: qt_method!(
        fn unmount_device(&self, path: QString) -> QString {
            match self.unmount_device_on_path(&path.to_string()) {
                Ok(_) => QString::from("success"),
                Err(e) => format!("error:{}", e).into(),
            }
        }
    ),
}

#[proxy(
    interface = "org.freedesktop.UDisks2.Filesystem",
    default_service = "org.freedesktop.UDisks2"
)]
trait Filesystem {
    fn mount(&self, options: HashMap<&str, zbus::zvariant::Value<'_>>) -> Result<String>;
    fn unmount(&self, options: HashMap<&str, zbus::zvariant::Value<'_>>) -> Result<()>;
}

impl Udisk {
    fn get_block_devices(&self) -> Result<Vec<serde_json::Value>> {
        let connection: Connection = Connection::system()?;
        let manager = ObjectManagerProxy::builder(&connection)
            .destination("org.freedesktop.UDisks2")?
            .path("/org/freedesktop/UDisks2")?
            .build()?;
        let objects = manager.get_managed_objects()?;

        let mut devices = Vec::new();

        for (path, interfaces) in objects.iter() {
            let (Some(block_props), Some(fs_props)) = (
                interfaces.get("org.freedesktop.UDisks2.Block"),
                interfaces.get("org.freedesktop.UDisks2.Filesystem"),
            ) else {
                continue;
            };

            let is_ignored = block_props
                .get("HintIgnore")
                .and_then(|v| bool::try_from(v).ok())
                .unwrap_or(false);

            if is_ignored {
                continue;
            }

            let mount_points = fs_props
                .get("MountPoints")
                .and_then(|v| <Vec<Vec<u8>>>::try_from(v.clone()).ok())
                .unwrap_or_default();
            let mount_paths: Vec<String> = mount_points
                .iter()
                .map(|bytes| {
                    String::from_utf8_lossy(bytes)
                        .trim_end_matches('\0')
                        .to_string()
                })
                .collect();

            let is_critical_os = mount_paths.iter().any(|p| {
                p == "/" || p.starts_with("/boot") || p.starts_with("/efi") || p == "/home"
            });

            if is_critical_os {
                continue;
            }

            let mut partition_name = block_props
                .get("IdLabel")
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or("Unknown")
                .to_string();

            if partition_name.is_empty() {
                let size_bytes = block_props
                    .get("Size")
                    .and_then(|v| u64::try_from(v).ok())
                    .unwrap_or(0);

                if size_bytes > 0 {
                    let size_gb = size_bytes as f64 / 1_073_741_824.0; // 1024^3

                    if size_gb >= 1.0 {
                        partition_name = format!("{:.1} GB Volume", size_gb);
                    } else {
                        let size_mb = size_bytes as f64 / 1_048_576.0;
                        partition_name = format!("{:.0} MB Volume", size_mb);
                    }
                } else {
                    partition_name = "Unknown Volume".to_string();
                }
            }

            let is_mounted = !mount_points.is_empty();

            let mount_point = if is_mounted {
                mount_paths[0].clone()
            } else {
                String::new()
            };

            devices.push(serde_json::json!({
                "name": partition_name,
                "path": path,
                "mount_point": mount_point,
                "mounted": is_mounted
            }));
        }

        devices.sort_by(|a, b| {
            let path_a = a["path"].as_str().unwrap_or("");
            let path_b = b["path"].as_str().unwrap_or("");
            path_a.cmp(path_b)
        });

        Ok(devices)
    }

    fn mount_device_on_path(&self, path: &str) -> Result<String> {
        let connection: Connection = Connection::system()?;
        let proxy = FilesystemProxyBlocking::builder(&connection)
            .path(path)?
            .build()?;

        let options: HashMap<&str, zbus::zvariant::Value> = HashMap::new();
        let mount_point = proxy.mount(options)?;
        Ok(mount_point)
    }

    fn unmount_device_on_path(&self, path: &str) -> Result<()> {
        let connection: Connection = Connection::system()?;
        let proxy = FilesystemProxyBlocking::builder(&connection)
            .path(path)?
            .build()?;

        let options: HashMap<&str, zbus::zvariant::Value> = HashMap::new();
        proxy.unmount(options)?;
        Ok(())
    }
}
