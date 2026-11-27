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
    visible: win.shown
    title: win.picker ? (win.picker.save ? "Save" : "Choose") : "Files"
    color: Appearance.colors.colLayer0

    // Rust backend bridges
    Fs { id: fs }
    Clipboard { id: clipboard }
    Tasks { id: tasks }
    Trash { id: trash }
    Portal { id: portal }

    // ---- Application State -------------------------------------------------
    property bool shown: !VoxelPortalMode
    property var picker: null

    property string curPath: ""
    property string curParent: ""
    property var entries: []
    property int index: -1
    property string status: ""

    property bool showHidden: false
    property string filter: ""
    property string sortBy: "Name"
    property bool rowLayout: false
    property bool previewVisible: false

    // Selected file paths: { "/path/to/file": true }
    property var selected: ({})
    property int anchor: -1
    property var cutPaths: ({})

    // Back / Forward navigation history stacks
    property var backStack: []
    property var forwardStack: []

    // Background state
    property string listingRaw: ""
    property int trashCount: 0
    property var pendingOp: ({})
    property var activeTasks: []

    // Hover tooltip state
    property int hoverIndex: -1
    property real hoverMouseX: 0
    property real hoverMouseY: 0
    property bool hoverPopupShown: false
    property var hoverEntryInfo: null

    // Standard user folders (Home, Desktop, Documents, etc.)
    property var xdgDirs: {
        try { return JSON.parse(fs.xdg_dirs()); }
        catch (e) { return {}; }
    }

    Component.onCompleted: {
        if (win.xdgDirs.home) {
            Appearance.themeLoader.filePath = win.xdgDirs.home + "/.local/state/sleex/user/generated/colors.json";
        }
        try {
            const config = JSON.parse(fs.load_config());
            if (config.sortBy) win.sortBy = config.sortBy;
            if (config.rowLayout !== undefined) win.rowLayout = !!config.rowLayout;
        } catch (e) {}
    }

    function saveConfig() {
        fs.save_config(win.sortBy, win.rowLayout);
    }

    // ---- Computed Properties -----------------------------------------------

    // True when any popup or dialog is currently open on screen
    readonly property bool overlayOpen:
        menu.shown || prompt.shown || confirm.shown || trashPanel.shown || quickLook.shown

    // Filtered and sorted list of files shown in the main view
    readonly property var visibleEntries: {
        const searchQuery = win.filter.toLowerCase();
        const sortMode = win.sortBy;
        const allEntries = win.entries || [];
        const filteredList = [];

        for (let i = 0; i < allEntries.length; i++) {
            const entry = allEntries[i];
            if (!win.showHidden && entry.hidden) continue;
            if (searchQuery.length > 0 && entry.name.toLowerCase().indexOf(searchQuery) < 0) continue;
            filteredList.push(entry);
        }

        if (sortMode && sortMode !== "Name") {
            filteredList.sort((a, b) => {
                // Always keep folders above files
                if (a.dir !== b.dir) return a.dir ? -1 : 1;

                const nameOrder = a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                if (sortMode === "Date") return (b.mtime - a.mtime) || nameOrder;
                if (sortMode === "Size") return (b.bytes - a.bytes) || nameOrder;
                if (sortMode === "Type") {
                    const extA = a.name.lastIndexOf(".") > 0 ? a.name.slice(a.name.lastIndexOf(".") + 1).toLowerCase() : "";
                    const extB = b.name.lastIndexOf(".") > 0 ? b.name.slice(b.name.lastIndexOf(".") + 1).toLowerCase() : "";
                    return extA.localeCompare(extB) || nameOrder;
                }
                return 0;
            });
        }

        return filteredList;
    }

    // How many visible items are currently selected
    readonly property int selectedCount: {
        const sel = win.selected || {};
        const list = win.visibleEntries;
        let count = 0;
        for (let i = 0; i < list.length; i++) {
            if (sel[list[i].path]) count++;
        }
        return count;
    }

    // Currently focused entry and hovered entry
    readonly property var activeEntry:
        (win.index >= 0 && win.index < win.visibleEntries.length) ? win.visibleEntries[win.index] : null

    readonly property var hoveredEntry:
        (win.hoverIndex >= 0 && win.hoverIndex < win.visibleEntries.length) ? win.visibleEntries[win.hoverIndex] : null

    // Path parts for the top breadcrumb bar (e.g. "/", "home", "user")
    readonly property var crumbs: {
        if (!win.curPath) return [];
        const list = [{ name: "/", path: "/" }];
        const parts = win.curPath.split("/").filter(part => part.length > 0);
        let builtPath = "";
        for (let i = 0; i < parts.length; i++) {
            builtPath += "/" + parts[i];
            list.push({ name: parts[i], path: builtPath });
        }
        return list;
    }

    onIndexChanged: {
        if (win.picker && win.picker.save && win.activeEntry && !win.activeEntry.dir) {
            statusBar.pickerFileName = win.activeEntry.name;
        }
    }

    onVisibleEntriesChanged: {
        if (win.visibleEntries.length === 0) {
            win.index = -1;
        } else if (win.index >= win.visibleEntries.length) {
            win.index = win.visibleEntries.length - 1;
        }
    }

    // ---- Hover Tooltip Logic -----------------------------------------------
    onHoverIndexChanged: {
        win.hoverPopupShown = false;
        win.hoverEntryInfo = null;
        if (win.hoverIndex >= 0 && !win.overlayOpen && !fileView.marqueeActive) {
            hoverTimer.restart();
        } else {
            hoverTimer.stop();
        }
    }

    onOverlayOpenChanged: if (win.overlayOpen) win.hideHoverPopup()

    function updateHover(newIndex, sceneX, sceneY) {
        win.hoverMouseX = sceneX;
        win.hoverMouseY = sceneY;
        if (win.hoverIndex !== newIndex) {
            win.hoverIndex = newIndex;
        } else if (win.hoverPopupShown) {
            win.positionHoverPopup();
        }
    }

    function hideHoverPopup() {
        win.hoverPopupShown = false;
        hoverTimer.stop();
    }

    function positionHoverPopup() {
        let popupX = win.hoverMouseX + 14;
        let popupY = win.hoverMouseY + 16;
        if (popupX + hoverPopup.width + 12 > win.width) {
            popupX = Math.max(8, win.hoverMouseX - hoverPopup.width - 10);
        }
        if (popupY + hoverPopup.height + 40 > win.height) {
            popupY = Math.max(56, win.hoverMouseY - hoverPopup.height - 10);
        }
        hoverPopup.x = popupX;
        hoverPopup.y = popupY;
    }

    // ---- Folder Navigation & Refreshing ------------------------------------
    function parseListing(rawJson) {
        try { return JSON.parse(rawJson); }
        catch (e) { return { error: "Could not read folder" }; }
    }

    // Load a new folder and reset selection and scroll position
    function load(path, keepFilter) {
        const raw = fs.list_json(path);
        const data = win.parseListing(raw);
        if (data.error !== undefined) {
            win.status = data.error;
            toast.show(data.error);
            return false;
        }

        win.hideHoverPopup();
        win.hoverIndex = -1;
        win.listingRaw = raw;
        win.curPath = data.path;
        win.curParent = data.parent;
        win.entries = data.entries || [];
        win.index = -1;
        win.selected = ({});
        win.anchor = -1;

        if (!keepFilter) {
            win.filter = "";
            topBar.filter = "";
        }

        win.status = win.entries.length + " items";
        fileView.resetScroll();
        return true;
    }

    // Open a folder and save the previous folder in the Back history
    function navigate(path, keepFilter) {
        const previousPath = win.curPath;
        if (!win.load(path, keepFilter)) return;
        if (previousPath !== "" && previousPath !== win.curPath) {
            win.backStack = win.backStack.concat([previousPath]);
            win.forwardStack = [];
        }
    }

    function historyBack() {
        if (win.backStack.length === 0) return;
        const target = win.backStack[win.backStack.length - 1];
        const previousPath = win.curPath;
        if (!win.load(target, false)) return;
        win.backStack = win.backStack.slice(0, -1);
        if (previousPath !== "") win.forwardStack = win.forwardStack.concat([previousPath]);
    }

    function historyForward() {
        if (win.forwardStack.length === 0) return;
        const target = win.forwardStack[win.forwardStack.length - 1];
        const previousPath = win.curPath;
        if (!win.load(target, false)) return;
        win.forwardStack = win.forwardStack.slice(0, -1);
        if (previousPath !== "") win.backStack = win.backStack.concat([previousPath]);
    }

    function goHome() { win.navigate(fs.home()); }
    function goUp() { if (win.curPath !== win.curParent) win.navigate(win.curParent); }

    // Update the current folder contents without losing scroll position or valid selections
    function applyListingInPlace(raw, selectPath) {
        const data = win.parseListing(raw);
        if (data.error !== undefined || data.path !== win.curPath) return;

        const targetPath = selectPath || (win.activeEntry ? win.activeEntry.path : null);
        const oldSelection = win.selected || {};

        win.listingRaw = raw;
        win.curParent = data.parent;
        win.entries = data.entries || [];
        win.status = win.entries.length + " items";

        // Keep only selected paths that still exist in the folder
        const existsMap = {};
        for (let i = 0; i < win.entries.length; i++) {
            existsMap[win.entries[i].path] = true;
        }

        const keptSelection = {};
        for (const path in oldSelection) {
            if (oldSelection[path] && existsMap[path]) {
                keptSelection[path] = true;
            }
        }
        win.selected = keptSelection;

        // Restore or update the focused item index
        if (targetPath && existsMap[targetPath]) {
            const list = win.visibleEntries;
            for (let i = 0; i < list.length; i++) {
                if (list[i].path === targetPath) {
                    win.index = i;
                    break;
                }
            }
            if (selectPath && win.index >= 0) {
                win.selectOnly(win.index);
                fileView.scrollToIndex(win.index);
            }
        }
    }

    function refresh(selectPath) {
        if (win.curPath === "") return;
        win.applyListingInPlace(fs.list_json(win.curPath), selectPath);
    }

    // Automatically check for external changes in the current folder
    function autoRefresh() {
        if (win.overlayOpen || win.curPath === "") return;
        const raw = fs.list_json(win.curPath);
        if (raw === win.listingRaw) return;

        // While a copy/move task is running, avoid flickering if the file list hasn't changed
        if (win.activeTasks.length > 0) {
            const data = win.parseListing(raw);
            const newEntries = data.entries || [];
            if (win.entries.length === newEntries.length) {
                let sameFiles = true;
                for (let i = 0; i < win.entries.length; i++) {
                    if (win.entries[i].path !== newEntries[i].path) {
                        sameFiles = false;
                        break;
                    }
                }
                if (sameFiles) {
                    win.listingRaw = raw;
                    return;
                }
            }
        }

        win.applyListingInPlace(raw, null);
    }

    // ---- Keyboard Cursor Movement & QuickLook ------------------------------
    function moveCursor(step) {
        const count = win.visibleEntries.length;
        if (count === 0) {
            win.index = -1;
            return;
        }
        if (win.index < 0) {
            win.index = step >= 0 ? 0 : count - 1;
        } else {
            win.index = ((win.index + step) % count + count) % count;
        }
        win.selectOnly(win.index);
        fileView.scrollToIndex(win.index);
    }

    function pageMove(direction) {
        const count = win.visibleEntries.length;
        if (count === 0) return;
        const base = win.index < 0 ? 0 : win.index;
        win.index = Math.max(0, Math.min(count - 1, base + direction * fileView.itemsPerPage));
        win.selectOnly(win.index);
        fileView.scrollToIndex(win.index);
    }

    function toggleCurrentSelection() {
        if (win.visibleEntries.length === 0) return;
        if (win.index < 0) win.index = 0;
        win.toggleSelect(win.index);
        if (win.index < win.visibleEntries.length - 1) {
            win.index += 1;
            fileView.scrollToIndex(win.index);
        }
    }

    function openQuickLook() {
        if (win.activeEntry) quickLook.open(win.activeEntry);
    }

    function quickLookStep(delta) {
        const list = win.visibleEntries;
        if (list.length === 0) return;
        win.index = Math.max(0, Math.min(list.length - 1, win.index + delta));
        fileView.scrollToIndex(win.index);
        quickLook.open(list[win.index]);
    }

    // ---- Selection Management ----------------------------------------------
    function isSelected(path) {
        return !!(win.selected && win.selected[path]);
    }

    function clearSelection() {
        win.selected = ({});
        win.index = -1;
        win.anchor = -1;
    }

    function selectOnly(itemIndex) {
        const entry = win.visibleEntries[itemIndex];
        if (!entry) return;
        const nextSelection = {};
        nextSelection[entry.path] = true;
        win.selected = nextSelection;
        win.anchor = itemIndex;
    }

    function toggleSelect(itemIndex) {
        const entry = win.visibleEntries[itemIndex];
        if (!entry) return;
        const nextSelection = Object.assign({}, win.selected || {});
        if (nextSelection[entry.path]) {
            delete nextSelection[entry.path];
        } else {
            nextSelection[entry.path] = true;
        }
        win.selected = nextSelection;
        win.anchor = itemIndex;
    }

    function selectRange(itemIndex) {
        const list = win.visibleEntries;
        if (win.anchor < 0 || win.anchor >= list.length) {
            win.selectOnly(itemIndex);
            return;
        }
        const start = Math.min(win.anchor, itemIndex);
        const end = Math.max(win.anchor, itemIndex);
        const nextSelection = {};
        for (let i = start; i <= end; i++) {
            if (list[i]) nextSelection[list[i].path] = true;
        }
        win.selected = nextSelection;
    }

    function selectAll() {
        const nextSelection = {};
        for (let i = 0; i < win.visibleEntries.length; i++) {
            nextSelection[win.visibleEntries[i].path] = true;
        }
        win.selected = nextSelection;
    }

    function selectedPaths() {
        const paths = [];
        const sel = win.selected || {};
        for (let i = 0; i < win.visibleEntries.length; i++) {
            const path = win.visibleEntries[i].path;
            if (sel[path]) paths.push(path);
        }
        if (paths.length === 0 && win.activeEntry) {
            paths.push(win.activeEntry.path);
        }
        return paths;
    }

    function handleItemClick(itemIndex, modifiers) {
        root.forceActiveFocus();
        win.index = itemIndex;
        if (modifiers & Qt.ControlModifier) {
            win.toggleSelect(itemIndex);
        } else if (modifiers & Qt.ShiftModifier) {
            win.selectRange(itemIndex);
        } else {
            win.selectOnly(itemIndex);
        }
    }

    // ---- Drag & Drop -------------------------------------------------------
    function dragUriList(itemIndex) {
        const entry = win.visibleEntries[itemIndex];
        if (!entry) return [];
        if (win.isSelected(entry.path) && win.selectedCount > 1) {
            return win.selectedPaths().map(path => Utils.fileUri(path));
        }
        return [Utils.fileUri(entry.path)];
    }

    function handleDrop(targetFolder, uris, isInternal) {
        if (!targetFolder || !uris || uris.length === 0) return;
        const joinedUris = uris.join("\n");
        if (isInternal) tasks.move_uris(targetFolder, joinedUris);
        else tasks.copy_uris(targetFolder, joinedUris);
        win.pollTasks();
    }

    // ---- Copy, Cut, Paste & Open -------------------------------------------
    function copySelection() {
        const paths = win.selectedPaths();
        if (paths.length === 0) return;
        win.cutPaths = ({});
        clipboard.copy_to_clipboard(paths.join("\n"));
        toast.show(paths.length === 1 ? "Copied" : ("Copied " + paths.length + " items"));
    }

    function cutSelection() {
        const paths = win.selectedPaths();
        if (paths.length === 0) return;
        const nextCut = {};
        for (let i = 0; i < paths.length; i++) {
            nextCut[paths[i]] = true;
        }
        win.cutPaths = nextCut;
        clipboard.cut_to_clipboard(paths.join("\n"));
        toast.show(paths.length === 1 ? "Cut" : ("Cut " + paths.length + " items"));
    }

    function copyPath() {
        if (!win.activeEntry) return;
        clipboard.copy_text(win.activeEntry.path);
        toast.show("Path copied");
    }

    function pasteClipboard() {
        if (clipboard.clipboard_has_image()) {
            const res = clipboard.paste_image(win.curPath);
            if (res.startsWith("error:")) {
                toast.show(res.slice(6));
            } else {
                win.cutPaths = ({});
                toast.show("Pasted image");
                win.refresh(res);
            }
            return;
        }
        const paths = clipboard.clipboard_paths();
        if (clipboard.clipboard_count() === 0 || !paths) {
            toast.show("Clipboard is empty");
            return;
        }
        if (clipboard.clipboard_is_cut()) {
            win.cutPaths = ({});
            clipboard.clear_clipboard();
            tasks.move_paths(win.curPath, paths);
        } else {
            tasks.copy_paths(win.curPath, paths, "Pasted");
        }
        win.pollTasks();
    }

    function openIndex(itemIndex) {
        const list = win.visibleEntries;
        if (itemIndex < 0 || itemIndex >= list.length) {
            if (win.picker && win.picker.save) win.pickerAccept();
            return;
        }
        const entry = list[itemIndex];
        if (entry.dir) {
            win.navigate(entry.path);
            return;
        }
        if (win.picker) {
            win.index = itemIndex;
            if (win.picker.save) {
                statusBar.pickerFileName = entry.name;
                win.pickerAccept();
            } else if (!win.picker.directory) {
                win.pickerAccept();
            }
            return;
        }
        const errorMsg = fs.open(entry.path);
        if (errorMsg) toast.show(errorMsg);
    }

    // ---- Create & Rename Files/Folders -------------------------------------
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

    function startRename(itemIndex) {
        const entry = win.visibleEntries[itemIndex];
        if (!entry) return;
        win.pendingOp = { type: "rename", path: entry.path };
        prompt.title = "Rename";
        prompt.glyph = entry.dir ? "folder" : "description";
        prompt.placeholder = "New name";
        prompt.value = entry.name;
        prompt.confirmLabel = "Rename";
        prompt.shown = true;
    }

    function promptAccept(inputText) {
        const name = (inputText || "").trim();
        if (name.length === 0 || name === "." || name === ".." || name.indexOf("/") >= 0) {
            toast.show("Invalid name");
            return;
        }

        const op = win.pendingOp || {};
        let errorMsg = "";
        let createdPath = null;

        if (op.type === "newfile") {
            errorMsg = fs.create_file(win.curPath, name);
            createdPath = Utils.joinPath(win.curPath, name);
        } else if (op.type === "newfolder") {
            errorMsg = fs.create_dir(win.curPath, name);
            createdPath = Utils.joinPath(win.curPath, name);
        } else if (op.type === "rename") {
            errorMsg = fs.rename(op.path, name);
            const parentFolder = op.path.substring(0, op.path.lastIndexOf("/"));
            createdPath = Utils.joinPath(parentFolder, name);
        }

        if (errorMsg) {
            toast.show(errorMsg);
            return;
        }
        toast.show(op.type === "rename" ? "Renamed" : "Created");
        win.refresh(createdPath);
    }

    // ---- Delete & Trash Operations -----------------------------------------
    function deleteCurrent(permanent) {
        const paths = win.selectedPaths();
        if (paths.length === 0) return;
        const names = paths.map(path => Utils.baseName(path));
        win.startDelete(paths, names, permanent);
    }

    function startDelete(paths, names, permanent) {
        win.pendingOp = { type: "delete", paths: paths, permanent: !!permanent };
        confirm.title = permanent ? "Delete permanently?" : "Move to Trash?";
        const targetLabel = paths.length > 1 ? (paths.length + " items") : names[0];
        confirm.message = permanent
            ? (targetLabel + " will be permanently deleted. This cannot be undone.")
            : (targetLabel + " will be moved to the trash.");
        confirm.confirmLabel = permanent ? "Delete" : "Trash";
        confirm.danger = permanent;
        confirm.shown = true;
    }

    function confirmAccept() {
        const op = win.pendingOp || {};
        if (op.type !== "delete") return;
        if (op.permanent) tasks.delete_paths(op.paths.join("\n"));
        else tasks.trash_paths(op.paths.join("\n"));
        win.pollTasks();
    }

    function openTrash() {
        trashPanel.reload();
        trashPanel.shown = true;
    }

    function trashDeletePermanent(names) {
        const errorMsg = fs.delete_permanent(names.join("\n"));
        if (errorMsg) {
            toast.show(errorMsg);
            return;
        }
        toast.show("Deleted");
        win.trashCount = trash.trash_count();
        trashPanel.reload();
    }

    // ---- Background Task Polling -------------------------------------------
    function pollTasks() {
        const raw = tasks.poll_json();
        if (!raw) return;
        let data;
        try { data = JSON.parse(raw); }
        catch (e) { return; }

        win.activeTasks = data.active || [];
        const completed = data.completed || [];
        if (completed.length === 0) return;

        let needTrashRefresh = false;

        for (let i = 0; i < completed.length; i++) {
            const task = completed[i];
            if (task.kind === "trash" || task.kind === "restore" || task.kind === "empty_trash" || task.kind === "delete") {
                needTrashRefresh = true;
            }

            if (task.cancelled) {
                toast.show("Operation cancelled");
            } else if (task.error && task.error.length > 0) {
                if (task.kind === "trash" && task.error === "error:EXDEV") {
                    const sourcePaths = (task.sourcePaths || "").split("\n").filter(s => s.length > 0);
                    const names = sourcePaths.map(path => Utils.baseName(path));
                    if (sourcePaths.length > 0) win.startDelete(sourcePaths, names, true);
                    toast.show("This drive has no trash folder");
                } else {
                    const cleanMsg = task.error.startsWith("error:") ? task.error.slice(6) : task.error;
                    toast.show(cleanMsg);
                }
            } else if (task.kind === "trash" && task.undoNames && task.undoNames.length > 0) {
                const undoList = task.undoNames;
                toast.showUndo(task.toast || "Trashed", function() {
                    tasks.restore_trash(undoList);
                    win.pollTasks();
                });
            } else if (task.toast && task.toast.length > 0) {
                toast.show(task.toast);
            }
        }

        win.refresh();
        if (needTrashRefresh) {
            win.trashCount = trash.trash_count();
            if (trashPanel.shown) trashPanel.reload();
        }
    }

    // ---- Right-Click Context Menu ------------------------------------------
    function openMenu(itemIndex, mouseX, mouseY) {
        if (itemIndex >= 0) {
            win.index = itemIndex;
            const clickedEntry = win.visibleEntries[itemIndex];
            if (clickedEntry && !win.isSelected(clickedEntry.path)) {
                win.selectOnly(itemIndex);
            }
        }

        const entry = itemIndex >= 0 ? win.visibleEntries[itemIndex] : null;
        const count = win.selectedCount;
        const items = [];

        if (entry) {
            items.push({ label: "Open", glyph: entry.dir ? "folder" : "description", act: "open" });
            items.push({ label: count > 1 ? ("Copy " + count + " items") : "Copy", glyph: "content_copy", act: "copy", key: "Ctrl+C" });
            items.push({ label: count > 1 ? ("Cut " + count + " items") : "Cut", glyph: "content_cut", act: "cut", key: "Ctrl+X" });
            items.push({ label: "Copy Path", glyph: "content_copy", act: "copypath", key: "Ctrl+⇧C" });
            items.push({ label: "Preview", glyph: "visibility", act: "preview", key: "Space" });
            if (count <= 1) {
                items.push({ label: "Rename", glyph: "edit", act: "rename", key: "F2" });
            }
            items.push({ sep: true });

            if (count > 1) {
                items.push({ label: "Move " + count + " items to Trash", glyph: "delete", act: "trash", key: "Del" });
            } else {
                items.push({ label: "Move to Trash", glyph: "delete", act: "trash", key: "Del" });
                items.push({ label: "Delete Permanently", glyph: "delete_forever", act: "delete", danger: true, key: "Del" });
            }
            items.push({ sep: true });
        }

        if (clipboard.clipboard_count() > 0 || clipboard.clipboard_has_image()) {
            items.push({ label: "Paste", glyph: "content_paste", act: "paste", key: "Ctrl+V" });
        }
        items.push({ label: "New Folder", glyph: "folder", act: "newfolder", key: "Ctrl+⇧N" });
        items.push({ label: "New File", glyph: "description", act: "newfile", key: "Ctrl+N" });
        items.push({ label: "Refresh", glyph: "refresh", act: "refresh", key: "F5" });

        menu.items = items;
        menu.x = Math.max(8, Math.min(mouseX, win.width - menu.width - 8));
        menu.y = Math.max(8, Math.min(mouseY, win.height - menu.height - 8));
        menu.shown = true;
    }

    function menuChoose(action) {
        menu.shown = false;
        if (action === "open") win.openIndex(win.index);
        else if (action === "copy") win.copySelection();
        else if (action === "cut") win.cutSelection();
        else if (action === "copypath") win.copyPath();
        else if (action === "preview") win.openQuickLook();
        else if (action === "paste") win.pasteClipboard();
        else if (action === "rename") win.startRename(win.index);
        else if (action === "trash") win.deleteCurrent(false);
        else if (action === "delete") win.deleteCurrent(true);
        else if (action === "newfolder") win.openNewFolder();
        else if (action === "newfile") win.openNewFile();
        else if (action === "refresh") win.refresh();
    }

    // ---- System File Picker (XDG Desktop Portal) ---------------------------
    function pollPortal() {
        const raw = portal.poll_portal();
        if (!raw) return;
        let request;
        try { request = JSON.parse(raw); }
        catch (e) { return; }

        win.picker = request;
        statusBar.pickerFileName = request.save ? (request.current_name || "") : "";
        win.shown = true;
        win.raise();
        win.requestActivate();

        const fallbackPath = (VoxelInitialPath && VoxelInitialPath !== "") ? VoxelInitialPath : fs.home();
        if (request.current_folder && request.current_folder !== "") {
            if (!win.load(request.current_folder, false)) win.navigate(fallbackPath);
        } else {
            win.navigate(fallbackPath);
        }
        if (request.save) statusBar.focusSaveInput();
    }

    function pickerAccept() {
        if (!win.picker) return;
        const entry = win.activeEntry;
        const chosenPaths = [];

        if (win.picker.save) {
            const fileName = statusBar.pickerFileName.trim();
            if (!fileName || fileName.indexOf("/") !== -1) {
                statusBar.focusSaveInput();
                return;
            }
            chosenPaths.push(Utils.joinPath(win.curPath, fileName));
        } else if (win.picker.directory) {
            chosenPaths.push((entry && entry.dir) ? entry.path : win.curPath);
        } else {
            if (entry && !entry.dir) chosenPaths.push(entry.path);
            else return;
        }
        win.pickerAnswer(0, chosenPaths);
    }

    function pickerCancel() {
        win.pickerAnswer(1, []);
    }

    function pickerAnswer(responseCode, paths) {
        if (win.picker && win.picker.handle) {
            portal.portal_reply(win.picker.handle, responseCode, paths.join("\n"));
        }
        win.picker = null;
        statusBar.pickerFileName = "";
        if (VoxelPortalMode) win.shown = false;
    }

    // ---- Main Window UI Layout ---------------------------------------------
    Item {
        id: root
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            const startPath = (VoxelInitialPath && VoxelInitialPath !== "") ? VoxelInitialPath : fs.home();
            win.navigate(startPath);
        }

        // Background timers
        Timer {
            id: hoverTimer
            interval: 320
            repeat: false
            onTriggered: {
                if (!win.hoveredEntry || win.overlayOpen || fileView.marqueeActive) return;
                try {
                    const parsed = JSON.parse(fs.entry_info(win.hoveredEntry.path, win.showHidden));
                    if (!parsed.error) win.hoverEntryInfo = parsed;
                } catch (e) {}
                win.positionHoverPopup();
                win.hoverPopupShown = true;
            }
        }

        Timer {
            interval: 200
            running: true
            repeat: true
            onTriggered: win.pollPortal()
        }

        Timer {
            interval: 50
            running: win.shown
            repeat: true
            onTriggered: win.pollTasks()
        }

        Timer {
            interval: 1000
            running: win.shown
            repeat: true
            onTriggered: {
                win.autoRefresh();
                win.trashCount = trash.trash_count();
            }
        }

        // Top toolbar
        TopBar {
            id: topBar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            crumbs: win.crumbs
            curPath: win.curPath
            showHidden: win.showHidden
            previewVisible: win.previewVisible
            trashCount: win.trashCount
            filter: win.filter
            sortBy: win.sortBy
            rowLayout: win.rowLayout

            onFilterChanged: win.filter = topBar.filter
            onSortChanged: (newSort) => { win.sortBy = newSort; win.saveConfig(); }
            onGoBack: win.historyBack()
            onGoForward: win.historyForward()
            onGoUp: win.goUp()
            onGoHome: win.goHome()
            onRefresh: win.refresh()
            onNavigate: (path) => win.navigate(path)
            onDropRequested: (path, uris, isInternal) => win.handleDrop(path, uris, isInternal)
            onToggleHidden: win.showHidden = !win.showHidden
            onTogglePreview: win.previewVisible = !win.previewVisible
            onOpenTrash: win.openTrash()
            onSearchAccepted: { root.forceActiveFocus(); win.openIndex(win.index); }
            onMoveUp: win.moveCursor(-1)
            onMoveDown: win.moveCursor(1)
            onEscaped: root.forceActiveFocus()
            onRowLayoutToggled: { win.rowLayout = !win.rowLayout; win.saveConfig(); }
        }

        // Left folder & drive sidebar
        Sidebar {
            id: sidebar
            anchors { left: parent.left; top: topBar.bottom; bottom: statusBar.top }
            curPath: win.curPath
            xdgDirs: win.xdgDirs
            onNavigate: (path) => win.navigate(path)
        }

        // Rounded inner corners where the sidebar meets the top and bottom bars
        RoundCorner {
            anchors { left: sidebar.right; top: topBar.bottom }
            size: Appearance.rounding.windowRounding
            color: Appearance.colors.colLayer2
            corner: cornerEnum.topLeft
            z: 10
        }

        RoundCorner {
            anchors { left: sidebar.right; bottom: statusBar.top }
            size: Appearance.rounding.windowRounding
            color: Appearance.colors.colLayer2
            corner: cornerEnum.bottomLeft
            z: 10
        }

        // Right preview panel
        PreviewPanel {
            id: previewPanel
            anchors {
                top: topBar.bottom; bottom: statusBar.top; right: parent.right
                rightMargin: 8; topMargin: 6; bottomMargin: 8
            }
            shown: win.previewVisible
            entry: win.activeEntry
            xdgDirs: win.xdgDirs
        }

        // Center file grid / list
        FileView {
            id: fileView
            anchors {
                left: sidebar.right; right: previewPanel.left
                top: topBar.bottom; bottom: statusBar.top
            }
            model: win.visibleEntries
            rowLayout: win.rowLayout
            hoverIndex: win.hoverIndex
            filtered: win.filter.length > 0
            xdgDirs: win.xdgDirs
            selectedMap: win.selected
            cutMap: win.cutPaths
            dragUrisForIndex: function(itemIndex) { return win.dragUriList(itemIndex); }

            onItemClicked: (idx, modifiers) => win.handleItemClick(idx, modifiers)
            onItemDoubleClicked: (idx) => win.openIndex(idx)
            onContextMenuRequested: (idx, x, y) => win.openMenu(idx, x, y)
            onDropRequested: (targetPath, uris, isInternal) => win.handleDrop(targetPath, uris, isInternal)
            onSelectionCleared: win.clearSelection()
            onMarqueeSelected: (newSelection) => { win.selected = newSelection; win.anchor = -1; }
            onHoverUpdated: (idx, x, y) => win.updateHover(idx, x, y)
            onInteractionStarted: win.hideHoverPopup()
        }

        // Bottom status bar
        StatusBar {
            id: statusBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            selectedCount: win.selectedCount
            visibleCount: win.visibleEntries.length
            totalCount: win.entries.length
            statusText: win.status
            pickerMode: win.picker !== null
            pickerDirectory: !!(win.picker && win.picker.directory)
            pickerSave: !!(win.picker && win.picker.save)

            onPickerCancel: win.pickerCancel()
            onPickerAccept: win.pickerAccept()
        }

        // ---- Keyboard Shortcuts --------------------------------------------
        Keys.onUpPressed: (event) => {
            if (!win.overlayOpen) { win.moveCursor(-fileView.columns); event.accepted = true; }
        }
        Keys.onDownPressed: (event) => {
            if (!win.overlayOpen) { win.moveCursor(fileView.columns); event.accepted = true; }
        }
        Keys.onReturnPressed: (event) => {
            if (!win.overlayOpen) { win.openIndex(win.index); event.accepted = true; }
        }
        Keys.onEnterPressed: (event) => {
            if (!win.overlayOpen) { win.openIndex(win.index); event.accepted = true; }
        }
        Keys.onBackPressed: (event) => {
            if (!win.overlayOpen) { win.goUp(); event.accepted = true; }
        }
        Keys.onEscapePressed: (event) => {
            if (menu.shown) { menu.shown = false; event.accepted = true; }
            else if (win.filter.length > 0) { win.filter = ""; topBar.filter = ""; event.accepted = true; }
            else if (win.selectedCount > 0 || win.index >= 0) { win.clearSelection(); event.accepted = true; }
            else if (!win.overlayOpen && win.picker) { win.pickerCancel(); event.accepted = true; }
        }

        Keys.onPressed: (event) => {
            if (win.overlayOpen && !menu.shown) return;

            const ctrl = !!(event.modifiers & Qt.ControlModifier);
            const shift = !!(event.modifiers & Qt.ShiftModifier);
            const alt = !!(event.modifiers & Qt.AltModifier);

            if (alt && event.key === Qt.Key_Left) { win.historyBack(); event.accepted = true; }
            else if (alt && event.key === Qt.Key_Right) { win.historyForward(); event.accepted = true; }
            else if (alt && event.key === Qt.Key_Up) { win.goUp(); event.accepted = true; }
            else if (event.key === Qt.Key_Left) { win.moveCursor(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { win.moveCursor(1); event.accepted = true; }
            else if (event.key === Qt.Key_PageUp) { win.pageMove(-1); event.accepted = true; }
            else if (event.key === Qt.Key_PageDown) { win.pageMove(1); event.accepted = true; }
            else if (event.key === Qt.Key_Home) {
                if (win.visibleEntries.length > 0) {
                    win.index = 0;
                    win.selectOnly(0);
                    fileView.scrollToIndex(0);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                if (win.visibleEntries.length > 0) {
                    win.index = win.visibleEntries.length - 1;
                    win.selectOnly(win.index);
                    fileView.scrollToIndex(win.index);
                }
                event.accepted = true;
            } else if (ctrl && event.key === Qt.Key_Space) { win.toggleCurrentSelection(); event.accepted = true; }
            else if (event.key === Qt.Key_Space) { win.openQuickLook(); event.accepted = true; }
            else if (ctrl && shift && event.key === Qt.Key_N) { win.openNewFolder(); event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_N) { win.openNewFile(); event.accepted = true; }
            else if (event.key === Qt.Key_F2) { win.startRename(win.index); event.accepted = true; }
            else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { win.deleteCurrent(shift); event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_H) { win.showHidden = !win.showHidden; event.accepted = true; }
            else if ((ctrl && event.key === Qt.Key_R) || event.key === Qt.Key_F5) { win.refresh(); event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_A) { win.selectAll(); event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_C) { if (shift) win.copyPath(); else win.copySelection(); event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_X) { win.cutSelection(); event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_V) { win.pasteClipboard(); event.accepted = true; }
            else if (event.key === Qt.Key_F3) { win.previewVisible = !win.previewVisible; event.accepted = true; }
            else if (ctrl && event.key === Qt.Key_F) { topBar.focusSearch(); event.accepted = true; }
            else if (!ctrl && !alt && event.text.length === 1 && event.text >= " ") { topBar.typeSearch(event.text); event.accepted = true; }
        }

        // ---- Popups, Menus & Overlays --------------------------------------

        // Click-outside catcher for closing the right-click menu
        MouseArea {
            anchors.fill: parent
            visible: menu.shown
            z: 90
            onClicked: menu.shown = false
        }

        ContextMenu {
            id: menu
            onChosen: (action) => win.menuChoose(action)
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
            onRestoreRequested: (names) => { tasks.restore_trash(names.join("\n")); win.pollTasks(); }
            onDeleteRequested: (names) => win.trashDeletePermanent(names)
            onEmptyRequested: { tasks.empty_trash(); win.pollTasks(); }
        }

        QuickLook {
            id: quickLook
            index: win.index
            total: win.visibleEntries.length
            xdgDirs: win.xdgDirs
            onStepRequested: (delta) => win.quickLookStep(delta)
            onClosed: root.forceActiveFocus()
        }

        HoverPopup {
            id: hoverPopup
            shown: win.hoverPopupShown && !win.overlayOpen && !fileView.marqueeActive
            entry: win.hoveredEntry
            info: win.hoverEntryInfo
        }

        ProgressPopup {
            anchors { right: parent.right; bottom: statusBar.top; rightMargin: 16; bottomMargin: 14 }
            tasks: win.activeTasks
            onCancelRequested: (taskId) => tasks.cancel(taskId)
        }

        Toast { id: toast }
    }
}
