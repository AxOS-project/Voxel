.pragma library

// Shared helper functions for checking file types and formatting text.

function isImage(entry) {
    if (!entry || entry.dir) return false;
    return /\.(png|jpe?g|gif|webp|svg|bmp|avif|ico|tiff?)$/i.test(entry.name);
}

function isAudio(entry) {
    if (!entry || entry.dir) return false;
    return /\.(mp3|flac|wav|ogg|oga|m4a|opus|aac|wma|alac)$/i.test(entry.name);
}

function isVideo(entry) {
    if (!entry || entry.dir) return false;
    return /\.(mp4|mkv|webm|mov|avi|m4v|ogv)$/i.test(entry.name);
}

function isText(entry) {
    if (!entry || entry.dir) return false;
    const hasTextExtension = /\.(txt|md|markdown|rst|log|conf|cfg|ini|toml|yaml|yml|json|xml|csv|tsv|sh|bash|zsh|fish|rs|py|js|mjs|cjs|ts|tsx|jsx|qml|c|h|cc|cpp|hpp|go|java|kt|lua|rb|php|sql|html|htm|css|scss|nix|kdl|desktop|service|diff|patch|env|gitignore|gitattributes|editorconfig)$/i.test(entry.name);
    const isKnownTextFile = /^(README|LICENSE|COPYING|Makefile|Dockerfile|flake\.lock|Cargo\.lock|CMakeLists\.txt|\.gitignore|\.bashrc|\.profile)/i.test(entry.name);
    return hasTextExtension || isKnownTextFile;
}

// Convert a raw byte count into a human-readable size string (e.g. "4.2 MB").
function fmtBytes(bytes) {
    if (!bytes || bytes <= 0) return "0 B";
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB";
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB";
    return (bytes / 1073741824).toFixed(1) + " GB";
}

// Format the size of a file entry, or return "--" for folders and symlinks.
function fmtSize(entry) {
    if (!entry || entry.dir || entry.link) return "--";
    return fmtBytes(entry.bytes);
}

// Convert a Unix timestamp (in seconds) into "YYYY-MM-DD HH:MM".
function fmtTime(seconds) {
    if (!seconds) return "--";
    const date = new Date(seconds * 1000);
    function pad(num) {
        return (num < 10 ? "0" : "") + num;
    }
    return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
         + " " + pad(date.getHours()) + ":" + pad(date.getMinutes());
}

// Convert milliseconds into "M:SS" for audio and video timers.
function fmtClock(milliseconds) {
    const totalSeconds = Math.floor(Math.max(0, milliseconds || 0) / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
}

// Build a short summary line for a file or folder (e.g. "Image · 1.2 MB · 2026-11-25 14:00").
function describe(entry) {
    if (!entry) return "";
    const parts = [];

    if (entry.link) parts.push("Symlink");
    else if (entry.dir) parts.push("Folder");
    else if (isImage(entry)) parts.push("Image");
    else if (isAudio(entry)) parts.push("Audio");
    else if (isVideo(entry)) parts.push("Video");
    else parts.push("File");

    if (!entry.dir && !entry.link) {
        parts.push(fmtSize(entry));
    }
    parts.push(fmtTime(entry.mtime));

    return parts.join("  ·  ");
}

// Return a Material Symbol icon name for a file or folder.
function iconFor(entry, xdgDirs) {
    if (!entry) return "description";
    if (entry.link) return "file_export";

    if (entry.dir) {
        if (xdgDirs) {
            if (entry.path === xdgDirs.desktop) return "desktop_windows";
            if (entry.path === xdgDirs.documents) return "description";
            if (entry.path === xdgDirs.download) return "file_download";
            if (entry.path === xdgDirs.music) return "library_music";
            if (entry.path === xdgDirs.pictures) return "photo_library";
            if (entry.path === xdgDirs.videos) return "video_library";
        }
        return "folder";
    }

    const name = entry.name.toLowerCase();
    if (/\.(png|jpe?g|gif|webp|svg|bmp|avif)$/.test(name)) return "image";
    if (/\.(mp3|flac|wav|ogg|m4a|opus)$/.test(name)) return "music_note";
    if (/\.(mp4|mkv|webm|mov|avi)$/.test(name)) return "video_file";
    if (/\.(zip|tar|gz|xz|zst|7z|rar)$/.test(name)) return "folder_zip";
    if (/\.(rs|py|js|ts|qml|c|cpp|h|go|sh|kdl|toml|json|yaml|yml)$/.test(name)) return "code";
    if (/\.pdf$/.test(name)) return "picture_as_pdf";
    return "description";
}

// Return a system desktop icon name for a special user folder, or "" if not a special folder.
function xdgFolderIcon(entry, xdgDirs) {
    if (!entry || !entry.dir || !xdgDirs) return "";
    if (entry.path === xdgDirs.desktop) return "user-desktop";
    if (entry.path === xdgDirs.documents) return "folder-documents";
    if (entry.path === xdgDirs.download) return "folder-download";
    if (entry.path === xdgDirs.music) return "folder-music";
    if (entry.path === xdgDirs.pictures) return "folder-pictures";
    if (entry.path === xdgDirs.videos) return "folder-videos";
    if (entry.path === xdgDirs.home) return "user-home";
    return "";
}

// Join a folder path and a file name into a full path.
function joinPath(dirPath, fileName) {
    if (!dirPath || dirPath === "/") return "/" + fileName;
    return dirPath.replace(/\/+$/, "") + "/" + fileName;
}

// Convert a local file path into a "file://" URL.
function fileUri(path) {
    if (!path) return "";
    return "file://" + path.split("/").map(encodeURIComponent).join("/");
}

// Return just the file or folder name from the end of a full path.
function baseName(path) {
    if (!path) return "";
    return path.split("/").pop();
}
