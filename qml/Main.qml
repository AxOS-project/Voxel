pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Voxel
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "components"
import "Utils.js" as Utils

Window {
    id: win

    width: 960
    height: 620
    minimumWidth: 520
    minimumHeight: 360
    visible: shown
    title: win.picker ? (win.picker.save ? "Save" : "Choose") : "Files"
    color: Appearance.colors.colLayer0

    // Hidden when started as a portal backend until a request arrives.
    property bool shown: !VoxelPortalMode
    // Active FileChooser request from the Rust portal backend, or null.
    property var picker: null

    // Rust backend, registered from main.rs as the QML module `Voxel`.
    Fs { id: fs }
    Preview { id: preview }
    Clipboard { id: clipboard }
    Tasks { id: tasks }
    Trash { id: trash }
    Portal { id: portal }

    Component.onCompleted: {
        // TODO: make this path configurable
        const home = xdgDirs.home;
        Appearance.themeLoader.filePath = home + "/.local/state/sleex/user/generated/colors.json"
        try {
            const cfg = JSON.parse(fs.load_config());
            if (cfg.sortBy) win.sortBy = cfg.sortBy;
            if (cfg.rowLayout !== undefined) win.rowLayout = !!cfg.rowLayout;
        } catch (e) {}
    }

    function saveConfig() {
        fs.save_config(win.sortBy, win.rowLayout);
    }

    // ---- state -------------------------------------------------------------
    property string curPath: ""
    property string curParent: ""
    property var entries: []
    property int index: -1
    property string status: ""
    property bool showHidden: false
    property string filter: ""
    property string sortBy: "Name"
    property var xdgDirs: {
        try { return JSON.parse(fs.xdg_dirs()); } catch(e) { return {}; }
    }
    // Preview side panel (photos / audio / metadata).
    property bool previewVisible: false
    // Multi-selection: path -> true. `anchor` is the shift-click origin.
    property var selected: ({})
    property int anchor: -1
    // Browser-style navigation history.
    property var backStack: []
    property var forwardStack: []
    // Raw JSON of the last listing, used to detect external changes.
    property string listingRaw: ""
    // Number of items currently in the trash (for the toolbar badge).
    property int trashCount: 0
    // Pending operation launched from a prompt/confirm dialog.
    property var pendingOp: ({})
    // Active background file operations shown in the bottom-right popup.
    property var activeTasks: []
    // Paths currently cut to the clipboard (path -> true).
    property var cutPaths: ({})
    // Whether newly created delegates should play the entrance animation.
    property bool animateEntrance: true
    // Suppress automatic view scrolling while restoring index in-place.
    property bool suppressIndexScroll: false

    // Rubber-band selection rectangle, in scene coordinates.
    property bool marqueeActive: false
    property real marqueeX0: 0
    property real marqueeY0: 0
    property real marqueeX1: 0
    property real marqueeY1: 0
    // Row index under the cursor (drives the hover highlight).
    property int hoverIndex: -1
    property real hoverMouseX: 0
    property real hoverMouseY: 0
    property bool hoverPopupShown: false
    property var hoverEntryInfo: null
    
    property bool rowLayout: false

    readonly property var hoveredEntry: {
        const list = win.visibleEntries;
        return (win.hoverIndex >= 0 && win.hoverIndex < list.length) ? list[win.hoverIndex] : null;
    }

    onHoverIndexChanged: {
        win.hoverPopupShown = false;
        win.hoverEntryInfo = null;
        if (win.hoverIndex >= 0 && !win.overlayOpen && !win.marqueeActive) {
            hoverTimer.restart();
        } else {
            hoverTimer.stop();
        }
    }

    onOverlayOpenChanged: if (win.overlayOpen) {
        win.hoverPopupShown = false;
        hoverTimer.stop();
    }

    function updateHover(idx, sx, sy) {
        win.hoverMouseX = sx;
        win.hoverMouseY = sy;
        if (win.hoverIndex !== idx) {
            win.hoverIndex = idx;
        } else if (win.hoverPopupShown) {
            win.positionHoverPopup();
        }
    }

    function hideHoverPopup() {
        win.hoverPopupShown = false;
        hoverTimer.stop();
    }

    function positionHoverPopup() {
        let px = win.hoverMouseX + 14;
        let py = win.hoverMouseY + 16;
        if (px + hoverPopup.width + 12 > win.width)
            px = Math.max(8, win.hoverMouseX - hoverPopup.width - 10);
        if (py + hoverPopup.height + 40 > win.height)
            py = Math.max(56, win.hoverMouseY - hoverPopup.height - 10);
        hoverPopup.x = px;
        hoverPopup.y = py;
    }

    readonly property bool overlayOpen:
        menu.shown || prompt.shown || confirm.shown || trashPanel.shown || quickLook.shown

    readonly property var visibleEntries: {
        const q = win.filter.toLowerCase();
        const sort = win.sortBy;
        const src = win.entries || [];
        const out = [];
        for (let i = 0; i < src.length; i++) {
            const e = src[i];
            if (!win.showHidden && e.hidden) continue;
            if (q.length > 0 && e.name.toLowerCase().indexOf(q) < 0) continue;
            out.push(e);
        }
        if (sort && sort !== "Name") {
            out.sort((a, b) => {
                if (a.dir !== b.dir) return a.dir ? -1 : 1;
                if (sort === "Date") return (b.mtime - a.mtime) || a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                if (sort === "Size") return (b.bytes - a.bytes) || a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                if (sort === "Type") {
                    const extA = a.name.lastIndexOf(".") > 0 ? a.name.slice(a.name.lastIndexOf(".") + 1).toLowerCase() : "";
                    const extB = b.name.lastIndexOf(".") > 0 ? b.name.slice(b.name.lastIndexOf(".") + 1).toLowerCase() : "";
                    return extA.localeCompare(extB) || a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                }
                return 0;
            });
        }
        return out;
    }

    // Number of selected entries that are currently visible.
    readonly property int selectedCount: {
        const sel = win.selected || {};
        const list = win.visibleEntries;
        let n = 0;
        for (let i = 0; i < list.length; i++) if (sel[list[i].path]) n++;
        return n;
    }

    // Entry under the cursor, and the one shown in the preview panel.
    readonly property var activeEntry: {
        const list = win.visibleEntries;
        return (win.index >= 0 && win.index < list.length) ? list[win.index] : null;
    }
    readonly property var previewEntry: win.activeEntry

    readonly property string imageSource:
        Utils.isImage(win.previewEntry) ? preview.file_uri(win.previewEntry.path) : ""
    readonly property string audioSource:
        Utils.isAudio(win.previewEntry) ? preview.file_uri(win.previewEntry.path) : ""
    readonly property string textSample:
        Utils.isText(win.previewEntry) ? preview.read_text(win.previewEntry.path, 8000) : ""

    readonly property var crumbs: {
        const p = win.curPath || "";
        const out = [];
        if (p === "") return out;
        out.push({ name: "/", path: "/" });
        const parts = p.split("/").filter(s => s.length > 0);
        let acc = "";
        for (let i = 0; i < parts.length; i++) {
            acc += "/" + parts[i];
            out.push({ name: parts[i], path: acc });
        }
        return out;
    }

    onIndexChanged: {
        if (index >= 0 && !win.suppressIndexScroll) {
            if (win.rowLayout) fileList.positionViewAtIndex(index, ListView.Contain)
            else fileGrid.positionViewAtIndex(index, GridView.Contain)
        }
        if (win.picker && win.picker.save && index >= 0 && index < win.visibleEntries.length) {
            const e = win.visibleEntries[index];
            if (e && !e.dir) status.pickerFileName = e.name;
        }
    }
    onVisibleEntriesChanged: {
        if (win.visibleEntries.length === 0) win.index = -1;
        else if (win.index >= win.visibleEntries.length) win.index = win.visibleEntries.length - 1;
    }

    // ---- navigation --------------------------------------------------------
    // Load a directory into the view without touching history.
    function load(path, keepFilter) {
        const raw = fs.list_json(path);
        let data;
        try { data = JSON.parse(raw); } catch (e) { data = { error: "parse error" }; }
        if (data.error !== undefined) {
            win.status = data.error;
            win.toastMsg(data.error);
            return false;
        }
        win.animateEntrance = true;
        entranceResetTimer.restart();
        win.hideHoverPopup();
        win.hoverIndex = -1;
        win.suppressIndexScroll = true;
        win.listingRaw = raw;
        win.curPath = data.path;
        win.curParent = data.parent;
        win.entries = data.entries;
        win.index = -1;
        win.selected = ({});
        win.anchor = -1;
        if (!keepFilter) { win.filter = ""; top.filter = ""; }
        win.status = (data.entries ? data.entries.length : 0) + " items";
        fileList.restoreViewState(-1, 0);
        fileGrid.restoreViewState(-1, 0);
        win.suppressIndexScroll = false;
        return true;
    }

    // Load a directory and record the move in the back/forward history.
    function navigate(path, keepFilter) {
        const from = win.curPath;
        if (!win.load(path, keepFilter)) return;
        if (from !== "" && from !== win.curPath) {
            win.backStack = win.backStack.concat([from]);
            win.forwardStack = [];
        }
    }

    function historyBack() {
        if (win.backStack.length === 0) return;
        const target = win.backStack[win.backStack.length - 1];
        const from = win.curPath;
        if (!win.load(target, false)) return;
        win.backStack = win.backStack.slice(0, -1);
        if (from !== "") win.forwardStack = win.forwardStack.concat([from]);
    }

    function historyForward() {
        if (win.forwardStack.length === 0) return;
        const target = win.forwardStack[win.forwardStack.length - 1];
        const from = win.curPath;
        if (!win.load(target, false)) return;
        win.forwardStack = win.forwardStack.slice(0, -1);
        if (from !== "") win.backStack = win.backStack.concat([from]);
    }

    // Apply a JSON directory listing in place without re-running entrance
    // animations or resetting the scroll position.
    function applyListingInPlace(raw, selectPath) {
        let data;
        try { data = JSON.parse(raw); } catch (e) { return; }
        if (data.error !== undefined || data.path !== win.curPath) return;

        const savedListY = fileList.contentY;
        const savedGridY = fileGrid.contentY;
        const activePath = selectPath !== undefined && selectPath !== null
            ? selectPath
            : (win.activeEntry ? win.activeEntry.path : null);
        const prev = win.selected || {};
        const wasSelected = [];
        for (const k in prev) if (prev[k]) wasSelected.push(k);

        win.animateEntrance = false;
        win.suppressIndexScroll = true;

        win.listingRaw = raw;
        win.curParent = data.parent;
        win.entries = data.entries;
        win.status = (data.entries ? data.entries.length : 0) + " items";

        const present = {};
        for (let i = 0; i < data.entries.length; i++) present[data.entries[i].path] = true;

        const next = {};
        let any = false;
        for (let i = 0; i < wasSelected.length; i++) {
            if (present[wasSelected[i]]) { next[wasSelected[i]] = true; any = true; }
        }
        win.selected = any ? next : ({});

        if (activePath !== null && present[activePath]) {
            const list = win.visibleEntries;
            for (let i = 0; i < list.length; i++) {
                if (list[i].path === activePath) { win.index = i; break; }
            }
            if (selectPath !== undefined && selectPath !== null && win.index >= 0) {
                win.selectOnly(win.index);
            }
        } else if (activePath === null) {
            win.index = -1;
        } else if (win.index >= win.visibleEntries.length) {
            win.index = win.visibleEntries.length - 1;
        }

        const restoreScroll = function() {
            fileList.restoreViewState(win.index, savedListY);
            fileGrid.restoreViewState(win.index, savedGridY);
        };
        restoreScroll();

        if (selectPath !== undefined && selectPath !== null) {
            win.suppressIndexScroll = false;
            if (win.rowLayout) fileList.positionViewAtIndex(win.index, ListView.Contain);
            else fileGrid.positionViewAtIndex(win.index, GridView.Contain);
        } else {
            Qt.callLater(function() {
                restoreScroll();
                win.suppressIndexScroll = false;
            });
        }
    }

    function refresh(selectPath) {
        if (win.curPath === "") return;
        const raw = fs.list_json(win.curPath);
        win.applyListingInPlace(raw, selectPath);
    }

    function pageMove(dir) {
        const n = win.visibleEntries.length;
        if (n === 0) return;
        let items = 1;
        if (win.rowLayout) {
            items = Math.max(1, Math.floor(fileList.listHeight / 36));
        } else {
            const cols = Math.max(1, Math.floor(fileGrid.gridWidth / fileGrid.cellWidth));
            const rows = Math.max(1, Math.floor(fileGrid.gridHeight / fileGrid.cellHeight));
            items = cols * rows;
        }
        const base = win.index < 0 ? 0 : win.index;
        win.index = Math.max(0, Math.min(n - 1, base + dir * items));
        win.selectOnly(win.index);
    }

    // Space: toggle the current row's selection and step down.
    function toggleCurrent() {
        if (win.visibleEntries.length === 0) return;
        if (win.index < 0) win.index = 0;
        win.toggleSelect(win.index);
        if (win.index < win.visibleEntries.length - 1) win.index += 1;
    }

    // Space: open the large preview for the current entry.
    function openQuickLook() {
        if (!win.activeEntry) return;
        quickLook.open(win.activeEntry);
    }

    // Advance the quick look by `delta`, clamped to the listing.
    function quickLookStep(delta) {
        const list = win.visibleEntries;
        if (list.length === 0) return;
        let i = win.index + delta;
        if (i < 0) i = 0;
        if (i >= list.length) i = list.length - 1;
        win.index = i;
        quickLook.open(list[i]);
    }

    // Poll the current directory and apply external changes in place, keeping
    // the filter, multi-selection and cursor position.
    function autoRefresh() {
        if (win.overlayOpen || win.curPath === "") return;
        const raw = fs.list_json(win.curPath);
        if (raw === win.listingRaw) return;
        if (win.activeTasks.length > 0) {
            let data;
            try { data = JSON.parse(raw); } catch (e) { return; }
            const oldEntries = win.entries || [];
            const newEntries = (data && data.entries) || [];
            if (oldEntries.length === newEntries.length) {
                let samePaths = true;
                for (let i = 0; i < oldEntries.length; i++) {
                    if (oldEntries[i].path !== newEntries[i].path) {
                        samePaths = false;
                        break;
                    }
                }
                if (samePaths) {
                    win.listingRaw = raw;
                    return;
                }
            }
        }
        win.applyListingInPlace(raw, undefined);
    }

    function goHome() { win.navigate(fs.home()); }
    function goUp() { if (win.curPath !== win.curParent) win.navigate(win.curParent); }

    function move(delta) {
        const n = win.visibleEntries.length;
        if (n === 0) { win.index = -1; return; }
        if (win.index < 0) {
            win.index = delta >= 0 ? 0 : n - 1;
        } else {
            win.index = ((win.index + delta) % n + n) % n;
        }
        win.selectOnly(win.index);
    }

    // ---- selection ---------------------------------------------------------
    function isSelected(path) { return !!(win.selected && win.selected[path]); }
    function isCut(path) { return !!(win.cutPaths && win.cutPaths[path]); }

    function clearSelection() {
        win.selected = ({});
        win.index = -1;
        win.anchor = -1;
    }

    function selectOnly(i) {
        const e = win.visibleEntries[i];
        if (!e) return;
        const next = {};
        next[e.path] = true;
        win.selected = next;
        win.anchor = i;
    }

    function toggleSelect(i) {
        const e = win.visibleEntries[i];
        if (!e) return;
        const next = {};
        const cur = win.selected || {};
        for (const k in cur) if (cur[k]) next[k] = true;
        if (next[e.path]) delete next[e.path]; else next[e.path] = true;
        win.selected = next;
        win.anchor = i;
    }

    function selectRange(i) {
        const list = win.visibleEntries;
        if (win.anchor < 0 || win.anchor >= list.length) { win.selectOnly(i); return; }
        const a = Math.min(win.anchor, i);
        const b = Math.max(win.anchor, i);
        const next = {};
        for (let k = a; k <= b; k++) if (list[k]) next[list[k].path] = true;
        win.selected = next;
    }

    function selectAll() {
        const next = {};
        const list = win.visibleEntries;
        for (let k = 0; k < list.length; k++) next[list[k].path] = true;
        win.selected = next;
    }

    // Selected paths in list order, falling back to the entry under the cursor.
    function selectedPaths() {
        const out = [];
        const sel = win.selected || {};
        const list = win.visibleEntries;
        for (let i = 0; i < list.length; i++) if (sel[list[i].path]) out.push(list[i].path);
        if (out.length === 0 && win.activeEntry) out.push(win.activeEntry.path);
        return out;
    }

    // `file://` URIs to drag from a row: the whole selection when the row is
    // selected, otherwise just that entry.
    function dragUriList(index) {
        const list = win.visibleEntries;
        const e = list[index];
        if (!e) return [];
        if (win.isSelected(e.path) && win.selectedCount > 1)
            return win.selectedPaths().map(p => preview.file_uri(p));
        return [preview.file_uri(e.path)];
    }

    // Handle a drop onto a folder row / breadcrumb. Internal drags move the
    // entries, drags from other applications copy them.
    function handleDrop(target, uris, internal) {
        if (!target || !uris || uris.length === 0) return;
        const joined = uris.join("\n");
        if (internal) tasks.move_uris(target, joined);
        else tasks.copy_uris(target, joined);
        win.pollTasks();
    }

    // ---- rubber-band selection --------------------------------------------
    function marqueeBegin(x, y) {
        win.marqueeActive = true;
        win.marqueeX0 = x;
        win.marqueeY0 = y;
        win.marqueeX1 = x;
        win.marqueeY1 = y;
    }

    function marqueeUpdate(x, y) {
        win.marqueeX1 = x;
        win.marqueeY1 = y;
        win.applyMarquee();
    }

    function marqueeEnd() { win.marqueeActive = false; }

    function applyMarquee() {
        const rx = Math.min(win.marqueeX0, win.marqueeX1);
        const ry = Math.min(win.marqueeY0, win.marqueeY1);
        const rw = Math.abs(win.marqueeX1 - win.marqueeX0);
        const rh = Math.abs(win.marqueeY1 - win.marqueeY0);
        if (win.rowLayout) {
            fileList.applyMarquee(rx, ry, rw, rh, fileList.contentX || 0, fileList.contentY);
        } else {
            fileGrid.applyMarquee(rx, ry, rw, rh, fileGrid.contentX || 0, fileGrid.contentY);
        }
    }
    function handleRowClick(i, modifiers) {
        root.forceActiveFocus();
        if (modifiers & Qt.ControlModifier) {
            win.index = i;
            win.toggleSelect(i);
        } else if (modifiers & Qt.ShiftModifier) {
            win.index = i;
            win.selectRange(i);
        } else {
            win.index = i;
            win.selectOnly(i);
        }
    }

    // ---- copy / cut / paste ------------------------------------------------
    function copySelection() {
        const paths = win.selectedPaths();
        if (paths.length === 0) return;
        win.cutPaths = ({});
        clipboard.copy_to_clipboard(paths.join("\n"));
        win.toastMsg(paths.length === 1 ? "Copied" : ("Copied " + paths.length + " items"));
    }

    function cutSelection() {
        const paths = win.selectedPaths();
        if (paths.length === 0) return;
        const nextCut = {};
        for (let i = 0; i < paths.length; i++) nextCut[paths[i]] = true;
        win.cutPaths = nextCut;
        clipboard.cut_to_clipboard(paths.join("\n"));
        win.toastMsg(paths.length === 1 ? "Cut" : ("Cut " + paths.length + " items"));
    }

    function copyPath() {
        if (!win.activeEntry) return;
        clipboard.copy_text(win.activeEntry.path);
        win.toastMsg("Path copied");
    }

    function pasteClipboard() {
        if (clipboard.clipboard_count() === 0) { win.toastMsg("Clipboard is empty"); return; }
        const paths = clipboard.clipboard_paths();
        if (!paths) { win.toastMsg("Clipboard is empty"); return; }
        if (clipboard.clipboard_is_cut()) {
            win.cutPaths = ({});
            clipboard.clear_clipboard();
            tasks.move_paths(win.curPath, paths);
        } else {
            tasks.copy_paths(win.curPath, paths, "Pasted");
        }
        win.pollTasks();
    }

    function openIndex(i) {
        const list = win.visibleEntries;
        if (i < 0 || i >= list.length) {
            if (win.picker && win.picker.save) win.pickerAccept();
            return;
        }
        const e = list[i];
        if (e.dir) { win.navigate(e.path); return; }
        if (win.picker) {
            win.index = i;
            if (win.picker.save) {
                status.pickerFileName = e.name;
                win.pickerAccept();
            } else if (!win.picker.directory) {
                win.pickerAccept();
            }
            return;
        }
        const err = fs.open(e.path);
        if (err) win.toastMsg(err);
    }

    // ---- toast -------------------------------------------------------------
    function toastMsg(t) { toast.show(t); }
    function toastUndo(t, names) {
        toast.showUndo(t, function() { win.undoTrash(names); });
    }

    // ---- create / rename ---------------------------------------------------
    function openNewFile() {
        win.pendingOp = { type: "newfile" };
        prompt.title = "New file";
        prompt.glyph = "insert_drive_file";
        prompt.placeholder = "File name";
        prompt.value = fs.suggest_name(win.curPath, "New File", "txt");
        prompt.confirmLabel = "Create";
        prompt.shown = true;
    }

    function openNewFolder() {
        win.pendingOp = { type: "newfolder" };
        prompt.title = "New folder";
        prompt.glyph = "folder";
        prompt.placeholder = "Folder name";
        prompt.value = fs.suggest_name(win.curPath, "New Folder", "");
        prompt.confirmLabel = "Create";
        prompt.shown = true;
    }

    function startRename(i) {
        const e = win.visibleEntries[i];
        if (!e) return;
        win.pendingOp = { type: "rename", path: e.path };
        prompt.title = "Rename";
        prompt.glyph = e.dir ? "folder" : "description";
        prompt.placeholder = "New name";
        prompt.value = e.name;
        prompt.confirmLabel = "Rename";
        prompt.shown = true;
    }

    function promptAccept(text) {
        const name = (text || "").trim();
        if (name.length === 0 || name === "." || name === ".." || name.indexOf("/") >= 0) {
            win.toastMsg("Invalid name");
            return;
        }
        const op = win.pendingOp || {};
        let err = "";
        let selectPath = null;
        if (op.type === "newfile") {
            err = fs.create_file(win.curPath, name);
            selectPath = Utils.joinPath(win.curPath, name);
        } else if (op.type === "newfolder") {
            err = fs.create_dir(win.curPath, name);
            selectPath = Utils.joinPath(win.curPath, name);
        } else if (op.type === "rename") {
            err = fs.rename(op.path, name);
            const parent = op.path.substring(0, op.path.lastIndexOf("/"));
            selectPath = Utils.joinPath(parent, name);
        }
        if (err) { win.toastMsg(err); return; }
        win.toastMsg(op.type === "rename" ? "Renamed" : "Created");
        win.refresh(selectPath);
    }

    // ---- delete ------------------------------------------------------------
    function deleteIndex(i, permanent) {
        const e = win.visibleEntries[i];
        if (!e) return;
        win.startDelete([e.path], [e.name], permanent);
    }

    function deleteSelection(permanent) {
        const paths = win.selectedPaths();
        if (paths.length === 0) return;
        const names = [];
        for (let i = 0; i < paths.length; i++) names.push(Utils.baseName(paths[i]));
        win.startDelete(paths, names, permanent);
    }

    // Delete the current selection (or the entry under the cursor).
    function deleteCurrent(permanent) {
        if (win.selectedCount > 0) win.deleteSelection(permanent);
        else win.deleteIndex(win.index, permanent);
    }

    function startDelete(paths, names, permanent) {
        win.pendingOp = { type: "delete", paths: paths, names: names, permanent: !!permanent };
        confirm.title = permanent ? "Delete permanently?" : "Move to Trash?";
        const what = paths.length > 1
            ? (paths.length + " items")
            : names[0];
        confirm.message = permanent
            ? what + " will be permanently deleted. This cannot be undone."
            : what + " will be moved to the trash.";
        confirm.confirmLabel = permanent ? "Delete" : "Trash";
        confirm.danger = permanent;
        confirm.shown = true;
    }

    function confirmAccept() {
        const op = win.pendingOp || {};
        if (op.type !== "delete") return;
        if (op.permanent) {
            tasks.delete_paths(op.paths.join("\n"));
            win.pollTasks();
            return;
        }
        tasks.trash_paths(op.paths.join("\n"));
        win.pollTasks();
    }

    // Undo the most recent trash operation.
    function undoTrash(names) {
        if (!names) return;
        tasks.restore_trash(names);
        win.pollTasks();
    }

    // ---- trash panel -------------------------------------------------------
    function openTrash() {
        trashPanel.reload();
        trashPanel.shown = true;
    }

    function trashRestore(names) {
        tasks.restore_trash(names.join("\n"));
        win.pollTasks();
    }

    function trashDelete(names) {
        const err = fs.delete_permanent(names.join("\n"));
        if (err) { win.toastMsg(err); return; }
        win.toastMsg("Deleted");
        win.trashCount = trash.trash_count();
        trashPanel.reload();
    }

    function trashEmpty() {
        tasks.empty_trash();
        win.pollTasks();
    }

    // ---- background task polling -------------------------------------------
    function pollTasks() {
        const raw = tasks.poll_json();
        if (!raw) return;
        let data;
        try { data = JSON.parse(raw); } catch (e) { return; }
        win.activeTasks = data.active || [];
        const done = data.completed || [];
        if (done.length > 0) {
            let needRefresh = false;
            let needTrashRefresh = false;
            for (let i = 0; i < done.length; i++) {
                const c = done[i];
                needRefresh = true;
                if (c.kind === "trash" || c.kind === "restore" || c.kind === "empty_trash" || c.kind === "delete") {
                    needTrashRefresh = true;
                }
                if (c.cancelled) {
                    win.toastMsg("Operation cancelled");
                } else if (c.error && c.error.length > 0) {
                    if (c.kind === "trash" && c.error === "error:EXDEV") {
                        const sp = (c.sourcePaths || "").split("\n").filter(s => s.length > 0);
                        const names = sp.map(p => Utils.baseName(p));
                        if (sp.length > 0) {
                            win.startDelete(sp, names, true);
                        }
                        win.toastMsg("This volume has no trash");
                    } else {
                        const msg = c.error.indexOf("error:") === 0 ? c.error.slice(6) : c.error;
                        win.toastMsg(msg);
                    }
                } else if (c.kind === "trash" && c.undoNames && c.undoNames.length > 0) {
                    win.toastUndo(c.toast || "Trashed", c.undoNames);
                } else if (c.toast && c.toast.length > 0) {
                    win.toastMsg(c.toast);
                }
            }
            if (needRefresh) win.refresh();
            if (needTrashRefresh) {
                win.trashCount = trash.trash_count();
                if (trashPanel.shown) trashPanel.reload();
            }
        }
    }

    // ---- context menu ------------------------------------------------------
    function openMenu(i, mx, my) {
        if (i >= 0) {
            win.index = i;
            const entry = win.visibleEntries[i];
            if (entry && !win.isSelected(entry.path)) win.selectOnly(i);
        }
        const e = i >= 0 ? win.visibleEntries[i] : null;
        const n = win.selectedCount;
        const items = [];
        if (e) {
            items.push({ label: "Open", glyph: e.dir ? "folder" : "description", act: "open" });
            items.push({
                label: n > 1 ? ("Copy " + n + " items") : "Copy",
                glyph: "content_copy", act: "copy", key: "Ctrl+C"
            });
            items.push({
                label: n > 1 ? ("Cut " + n + " items") : "Cut",
                glyph: "content_cut", act: "cut", key: "Ctrl+X"
            });
            items.push({ label: "Copy Path", glyph: "content_copy", act: "copypath", key: "Ctrl+\u21e7C" });
            items.push({ label: "Preview", glyph: "visibility", act: "preview", key: "Space" });
            if (n <= 1) items.push({ label: "Rename", glyph: "edit", act: "rename", key: "F2" });
            items.push({ sep: true });
            if (n > 1) items.push({
                label: "Move " + n + " items to Trash", glyph: "delete", act: "trash", key: "Del"
            });
            else {
                items.push({ label: "Move to Trash", glyph: "delete", act: "trash", key: "Del" });
                items.push({ label: "Delete Permanently", glyph: "delete_forever", act: "delete", danger: true, key: "Del" });
            }
            items.push({ sep: true });
        }
        if (clipboard.clipboard_count() > 0)
            items.push({ label: "Paste", glyph: "content_paste", act: "paste", key: "Ctrl+V" });
        items.push({ label: "New Folder", glyph: "folder", act: "newfolder", key: "Ctrl+N" });
        items.push({ label: "New File", glyph: "description", act: "newfile", key: "Ctrl+N" });
        items.push({ label: "Refresh", glyph: "refresh", act: "refresh", key: "F5" });

        let h = 8;
        for (let k = 0; k < items.length; k++) h += items[k].sep ? menu.sepHeight : menu.rowHeight;
        menu.items = items;
        menu.x = Math.max(8, Math.min(mx, win.width - menu.width - 8));
        menu.y = Math.max(8, Math.min(my, win.height - h - 8));
        menu.shown = true;
    }

    function menuChoose(act) {
        const i = win.index;
        if (act === "open") win.openIndex(i);
        else if (act === "copy") win.copySelection();
        else if (act === "cut") win.cutSelection();
        else if (act === "copypath") win.copyPath();
        else if (act === "preview") win.openQuickLook();
        else if (act === "paste") win.pasteClipboard();
        else if (act === "rename") win.startRename(i);
        else if (act === "trash") {
            if (win.selectedCount > 1) win.deleteSelection(false);
            else win.deleteIndex(i, false);
        } else if (act === "delete") {
            if (win.selectedCount > 1) win.deleteSelection(true);
            else win.deleteIndex(i, true);
        }
        else if (act === "newfolder") win.openNewFolder();
        else if (act === "newfile") win.openNewFile();
        else if (act === "refresh") win.refresh();
    }

    // ---- portal picker -----------------------------------------------------
    function pollPortal() {
        const raw = portal.poll_portal();
        if (!raw) return;
        let req;
        try { req = JSON.parse(raw); } catch (e) { return; }
        win.picker = req;
        status.pickerFileName = req.save ? (req.current_name || "") : "";
        win.shown = true;
        win.raise();
        win.requestActivate();
        const fallback = (VoxelInitialPath && VoxelInitialPath !== "") ? VoxelInitialPath : fs.home();
        if (req.current_folder && req.current_folder !== "") {
            if (!win.load(req.current_folder, false)) win.navigate(fallback);
        } else {
            win.navigate(fallback);
        }
        if (req.save) status.focusSaveInput();
    }

    function pickerAccept() {
        if (!win.picker) return;
        const list = win.visibleEntries;
        const e = list[win.index];
        const paths = [];
        if (win.picker.save) {
            const name = status.pickerFileName.trim();
            if (!name || name.indexOf("/") !== -1) {
                status.focusSaveInput();
                return;
            }
            const base = win.curPath === "/" ? "" : win.curPath;
            paths.push(base + "/" + name);
        } else if (win.picker.directory) {
            paths.push((e && e.dir) ? e.path : win.curPath);
        } else {
            if (e && !e.dir) paths.push(e.path);
            else return;
        }
        win.pickerAnswer(0, paths);
    }

    function pickerCancel() { win.pickerAnswer(1, []); }

    function pickerAnswer(code, paths) {
        if (win.picker && win.picker.handle) portal.portal_reply(win.picker.handle, code, paths.join("\n"));
        win.picker = null;
        status.pickerFileName = "";
        if (VoxelPortalMode) win.shown = false;
    }

    // ---- root container ----------------------------------------------------
    Item {
        id: root
        anchors.fill: parent
        focus: true

        Component.onCompleted: win.navigate(
            (VoxelInitialPath && VoxelInitialPath !== "") ? VoxelInitialPath : fs.home())

        // subtle top glow for depth
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 140
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.035) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Disable delegate entrance animations once the initial directory load finishes.
        Timer {
            id: entranceResetTimer
            interval: 350
            repeat: false
            onTriggered: win.animateEntrance = false
        }

        // Show hover metadata popup after a brief pause on an entry.
        Timer {
            id: hoverTimer
            interval: 320
            repeat: false
            onTriggered: {
                if (!win.hoveredEntry || win.overlayOpen || win.marqueeActive) return;
                const raw = fs.entry_info(win.hoveredEntry.path, win.showHidden);
                try {
                    const parsed = JSON.parse(raw);
                    if (!parsed.error) win.hoverEntryInfo = parsed;
                } catch (e) {}
                win.positionHoverPopup();
                win.hoverPopupShown = true;
            }
        }

        // Poll the Rust portal backend for pending FileChooser requests.
        Timer {
            interval: 200
            running: true
            repeat: true
            onTriggered: win.pollPortal()
        }

        // Poll background file operations (copy, move, delete, etc.).
        Timer {
            interval: 50
            running: win.shown
            repeat: true
            onTriggered: win.pollTasks()
        }

        // Watch the current directory so the listing stays in sync with the
        // filesystem without a manual refresh.
        Timer {
            interval: 1000
            running: win.shown
            repeat: true
            onTriggered: {
                win.autoRefresh();
                win.trashCount = trash.trash_count();
            }
        }

        TopBar {
            id: top
            anchors { left: parent.left; right: parent.right; top: parent.top }
            crumbs: win.crumbs
            curPath: win.curPath
            showHidden: win.showHidden
            previewVisible: win.previewVisible
            trashCount: win.trashCount
            filter: win.filter
            sortBy: win.sortBy
            rowLayout: win.rowLayout

            onFilterChanged: win.filter = top.filter
            onSortChanged: (s) => { win.sortBy = s; win.saveConfig(); }
            onGoBack: win.historyBack()
            onGoForward: win.historyForward()
            onGoUp: win.goUp()
            onGoHome: win.goHome()
            onRefresh: win.refresh()
            onNavigate: (path) => win.navigate(path)
            onDropRequested: (path, uris, internal) => win.handleDrop(path, uris, internal)
            onToggleHidden: win.showHidden = !win.showHidden
            onTogglePreview: win.previewVisible = !win.previewVisible
            onOpenTrash: win.openTrash()
            onSearchAccepted: { root.forceActiveFocus(); win.openIndex(win.index); }
            onMoveUp: win.move(-1)
            onMoveDown: win.move(1)
            onEscaped: root.forceActiveFocus()
            onRowLayoutToggled: { win.rowLayout = !win.rowLayout; win.saveConfig(); }
        }

        Sidebar {
            id: sidebar
            anchors {
                left: parent.left
                top: top.bottom; bottom: status.top
            }
            curPath: win.curPath
            xdgDirs: win.xdgDirs
            onNavigate: (path) => win.navigate(path)
        }

        RoundCorner {
            anchors.left: sidebar.right
            anchors.top: top.bottom
            size: Appearance.rounding.windowRounding
            color: Appearance.colors.colLayer2
            corner: cornerEnum.topLeft
            z: 10
        }

        RoundCorner {
            anchors.left: sidebar.right
            anchors.bottom: status.top
            size: Appearance.rounding.windowRounding
            color: Appearance.colors.colLayer2
            corner: cornerEnum.bottomLeft
            z: 10
        }

        // ---- preview panel -------------------------------------------------
        PreviewPanel {
            id: previewPanel
            anchors {
                top: top.bottom; bottom: status.top
                right: parent.right; rightMargin: 8
                topMargin: 6; bottomMargin: 8
            }
            shown: win.previewVisible
            entry: win.previewEntry
            imageSource: win.imageSource
            audioSource: win.audioSource
            textSample: win.textSample
        }

        FileGrid {
            id: fileGrid
            visible: !win.rowLayout
            anchors {
                left: sidebar.right; right: previewPanel.left
                top: top.bottom; bottom: status.top
            }
            xdgDirs: win.xdgDirs
            model: win.visibleEntries
            currentIndex: win.index
            hoverIndex: win.hoverIndex
            anchorIndex: win.anchor
            filtered: win.filter.length > 0
            marqueeActive: win.marqueeActive
            marqueeX0: win.marqueeX0
            marqueeY0: win.marqueeY0
            marqueeX1: win.marqueeX1
            marqueeY1: win.marqueeY1

            onRowContext: (idx, x, y) => win.openMenu(idx, x, y)
            onDropRequested: (target, uris, internal) => win.handleDrop(target, uris, internal)
            onEmptyContext: (x, y) => win.openMenu(-1, x, y)
            onRowClicked: (idx, modifiers) => win.handleRowClick(idx, modifiers)
            onDoubleClicked: (idx) => win.openIndex(idx)
            onSelectionCleared: win.clearSelection()

            onMarqueeBegin: (x, y) => win.marqueeBegin(x, y)
            onMarqueeUpdate: (x, y) => win.marqueeUpdate(x, y)
            onMarqueeEnd: () => win.marqueeEnd()
            onApplyMarquee: (rx, ry, rw, rh, cx, cy) => {
                const next = {};
                const entries = win.visibleEntries;
                const cols = Math.max(1, Math.floor(fileGrid.gridWidth / fileGrid.cellWidth));
                for (let i = 0; i < entries.length; i++) {
                    const ix = (i % cols) * fileGrid.cellWidth;
                    const iy = Math.floor(i / cols) * fileGrid.cellHeight;
                    if (ix < rx + rw + cx && ix + fileGrid.cellWidth > rx + cx
                            && iy < ry + rh + cy && iy + fileGrid.cellHeight > ry + cy)
                        next[entries[i].path] = true;
                }
                win.selected = next;
                win.anchor = -1;
            }
        }

        FileList {
            id: fileList
            visible: win.rowLayout
            anchors {
                left: sidebar.right; right: previewPanel.left
                top: top.bottom; bottom: status.top
            }
            xdgDirs: win.xdgDirs
            model: win.visibleEntries
            currentIndex: win.index
            hoverIndex: win.hoverIndex
            anchorIndex: win.anchor
            filtered: win.filter.length > 0
            marqueeActive: win.marqueeActive
            marqueeX0: win.marqueeX0
            marqueeY0: win.marqueeY0
            marqueeX1: win.marqueeX1
            marqueeY1: win.marqueeY1

            onRowContext: (idx, x, y) => win.openMenu(idx, x, y)
            onDropRequested: (target, uris, internal) => win.handleDrop(target, uris, internal)
            onEmptyContext: (x, y) => win.openMenu(-1, x, y)
            onRowClicked: (idx, modifiers) => win.handleRowClick(idx, modifiers)
            onDoubleClicked: (idx) => win.openIndex(idx)
            onSelectionCleared: win.clearSelection()

            onMarqueeBegin: (x, y) => win.marqueeBegin(x, y)
            onMarqueeUpdate: (x, y) => win.marqueeUpdate(x, y)
            onMarqueeEnd: () => win.marqueeEnd()
            onApplyMarquee: (rx, ry, rw, rh, cx, cy) => {
                const next = {};
                const entries = win.visibleEntries;
                for (let i = 0; i < entries.length; i++) {
                    const iy = i * 36;
                    if (0 < rx + rw + cx && fileList.listWidth > rx + cx
                            && iy < ry + rh + cy && iy + 36 > ry + cy)
                        next[entries[i].path] = true;
                }
                win.selected = next;
                win.anchor = -1;
            }
        }


        StatusBar {
            id: status
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            selectedCount: win.selectedCount
            visibleCount: win.visibleEntries.length
            totalCount: win.entries.length
            statusText: win.status
            pickerMode: win.picker !== null
            pickerDirectory: win.picker && win.picker.directory
            pickerSave: win.picker && win.picker.save

            onPickerCancel: win.pickerCancel()
            onPickerAccept: win.pickerAccept()
        }

        // ---- keyboard ------------------------------------------------------
        Keys.onUpPressed: (e) => {
            if (!win.overlayOpen) {
                const cols = win.rowLayout ? 1 : Math.max(1, Math.floor(fileGrid.gridWidth / fileGrid.cellWidth));
                win.move(-cols);
                e.accepted = true;
            }
        }
        Keys.onDownPressed: (e) => {
            if (!win.overlayOpen) {
                const cols = win.rowLayout ? 1 : Math.max(1, Math.floor(fileGrid.gridWidth / fileGrid.cellWidth));
                win.move(cols);
                e.accepted = true;
            }
        }
        Keys.onReturnPressed: (e) => { if (!win.overlayOpen) { win.openIndex(win.index); e.accepted = true; } }
        Keys.onEnterPressed: (e) => { if (!win.overlayOpen) { win.openIndex(win.index); e.accepted = true; } }
        Keys.onBackPressed: (e) => { if (!win.overlayOpen) { win.goUp(); e.accepted = true; } }
        Keys.onEscapePressed: (e) => {
            if (menu.shown) { menu.shown = false; e.accepted = true; }
            else if (win.filter.length > 0) { win.filter = ""; top.filter = ""; e.accepted = true; }
            else if (win.selectedCount > 0 || win.index >= 0) { win.clearSelection(); e.accepted = true; }
            else if (!win.overlayOpen) { if (win.picker) { win.pickerCancel(); } e.accepted = true; }
        }
        Keys.onPressed: (e) => {
            if (win.overlayOpen && !menu.shown) { return; }
            const ctrl = e.modifiers & Qt.ControlModifier;
            const shift = e.modifiers & Qt.ShiftModifier;
            const alt = e.modifiers & Qt.AltModifier;
            if (alt && e.key === Qt.Key_Left) {
                win.historyBack();
                e.accepted = true;
            } else if (alt && e.key === Qt.Key_Right) {
                win.historyForward();
                e.accepted = true;
            } else if (alt && e.key === Qt.Key_Up) {
                win.goUp();
                e.accepted = true;
            } else if (e.key === Qt.Key_Backspace) {
                win.deleteCurrent(!!shift);
                e.accepted = true;
            } else if (e.key === Qt.Key_Left) {
                win.move(-1);
                e.accepted = true;
            } else if (e.key === Qt.Key_Right) {
                win.move(1);
                e.accepted = true;
            } else if (e.key === Qt.Key_PageUp) {
                win.pageMove(-1);
                e.accepted = true;
            } else if (e.key === Qt.Key_PageDown) {
                win.pageMove(1);
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_Space) {
                win.toggleCurrent();
                e.accepted = true;
            } else if (e.key === Qt.Key_Space) {
                win.openQuickLook();
                e.accepted = true;
            } else if (ctrl && shift && e.key === Qt.Key_N) {
                win.openNewFolder();
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_N) {
                win.openNewFile();
                e.accepted = true;
            } else if (e.key === Qt.Key_F2) {
                win.startRename(win.index);
                e.accepted = true;
            } else if (e.key === Qt.Key_Delete) {
                win.deleteCurrent(!!shift);
                e.accepted = true;
            } else if (e.key === Qt.Key_Home) {
                if (win.visibleEntries.length > 0) { win.index = 0; win.selectOnly(0); }
                e.accepted = true;
            } else if (e.key === Qt.Key_End) {
                if (win.visibleEntries.length > 0) {
                    win.index = win.visibleEntries.length - 1;
                    win.selectOnly(win.index);
                }
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_H) {
                win.showHidden = !win.showHidden;
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_R || e.key === Qt.Key_F5) {
                win.refresh();
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_A) {
                win.selectAll();
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_C) {
                if (shift) win.copyPath(); else win.copySelection();
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_X) {
                win.cutSelection();
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_V) {
                win.pasteClipboard();
                e.accepted = true;
            } else if (e.key === Qt.Key_F3) {
                win.previewVisible = !win.previewVisible;
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_F) {
                top.focusSearch();
                e.accepted = true;
            } else if (!ctrl && !alt && e.text.length === 1 && e.text >= " ") {
                top.typeSearch(e.text);
                e.accepted = true;
            }
        }

        // ---- context menu backdrop ----------------------------------------
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            visible: menu.shown
            z: 90
            MouseArea { anchors.fill: parent; onClicked: menu.shown = false }
        }

        ContextMenu {
            id: menu
            onChosen: (act) => win.menuChoose(act)
        }

        PromptDialog {
            id: prompt
            onAccepted: (text) => { prompt.shown = false; root.forceActiveFocus(); win.promptAccept(text); }
            onCancelled: { prompt.shown = false; root.forceActiveFocus(); }
        }

        ConfirmDialog {
            id: confirm
            onConfirmed: { confirm.shown = false; root.forceActiveFocus(); win.confirmAccept(); }
            onCancelled: { confirm.shown = false; root.forceActiveFocus(); }
        }

        TrashPanel {
            id: trashPanel
            loadList: function() { return trash.trash_list(); }
            onRestoreRequested: (names) => win.trashRestore(names)
            onDeleteRequested: (names) => win.trashDelete(names)
            onEmptyRequested: win.trashEmpty()
        }

        QuickLook {
            id: quickLook
            index: win.index
            total: win.visibleEntries.length
            fileUri: function(path) { return preview.file_uri(path); }
            readText: function(path, max) { return preview.read_text(path, max); }
            onStepRequested: (delta) => win.quickLookStep(delta)
            onClosed: root.forceActiveFocus()
        }

        HoverPopup {
            id: hoverPopup
            shown: win.hoverPopupShown && !win.overlayOpen && !win.marqueeActive
            entry: win.hoveredEntry
            info: win.hoverEntryInfo
        }

        ProgressPopup {
            id: progressPopup
            anchors {
                right: parent.right
                bottom: status.top
                rightMargin: 16
                bottomMargin: 14
            }
            tasks: win.activeTasks
            onCancelRequested: (taskId) => tasks.cancel(taskId)
        }

        Toast { id: toast }
    }
}
