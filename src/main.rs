use qmetaobject::prelude::*;
use qmetaobject::QUrl;

fn main() {
    std::env::set_var("QT_QUICK_CONTROLS_STYLE", "Basic");
    std::env::remove_var("QT_STYLE_OVERRIDE");
    qmetaobject::log::init_qt_to_rust();
    env_logger::builder()
        .parse_env(env_logger::Env::default().default_filter_or("warn"))
        .init();

    let args: Vec<String> = std::env::args().collect();
    let portal_mode = args.iter().any(|a| a == "--portal");
    let initial = args
        .iter()
        .skip(1)
        .find(|a| !a.starts_with("--"))
        .map(|a| voxel::util::text::from_uri(a))
        .unwrap_or_default();

    voxel::register_qml();

    // Serve the FileChooser portal regardless of mode so the running instance
    // can act as the system picker.
    voxel::portal::serve();

    let mut engine = QmlEngine::new();
    engine.set_property("VoxelInitialPath".into(), QString::from(initial.as_str()).into());
    engine.set_property("VoxelPortalMode".into(), portal_mode.into());
    match std::env::var("VOXEL_QML") {
        Ok(path) => engine.load_file(path.into()),
        Err(_) => engine.load_url(QUrl::from(QString::from("qrc:/qml/Main.qml"))),
    }
    engine.exec();
}
