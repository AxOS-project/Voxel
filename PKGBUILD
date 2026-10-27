pkgname=voxel
pkgver=0.1.1
pkgrel=1
pkgdesc="A file manager for Sleex written in Rust and QML"
arch=('x86_64')
url="https://github.com/axos-project/voxel"
license=('MIT')
depends=(
    'qt5-base'
    'qt5-declarative'
    'qt5-svg'
    'hicolor-icon-theme'
)
makedepends=(
    'cargo'
)
source=()
sha256sums=()

build() {
    cd $startdir

    unset CFLAGS CXXFLAGS LDFLAGS RUSTFLAGS

    export CXXFLAGS="-fno-lto"
    export CFLAGS="-fno-lto"

    cargo build --release
}

package() {
    cd $startdir

    install -Dm755 "target/release/voxel" "$pkgdir/usr/bin/voxel"
    
    install -Dm644 "assets/voxel.desktop" "$pkgdir/usr/share/applications/voxel.desktop"
    install -Dm644 "assets/voxel.portal" "$pkgdir/usr/share/xdg-desktop-portal/portals/voxel.portal"
    install -Dm644 "assets/org.freedesktop.impl.portal.desktop.voxel.service" "$pkgdir/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.voxel.service"
    install -Dm644 "assets/voxel-portal.service" "$pkgdir/usr/lib/systemd/user/voxel-portal.service"
}