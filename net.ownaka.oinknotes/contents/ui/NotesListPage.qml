import QtQuick
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel
import "shared"
import "shared/NoteStore.js" as NoteStore
import "shared/MarkdownUtils.js" as MarkdownUtils

Item {
    id: root

    property var style
    signal openNote(string id)

    property string searchQuery: ""
    property var pinnedIds: []
    property var allNotes: []
    property string confirmDeleteId: ""

    FolderListModel {
        id: folderModel
        folder: style && style.notesFolder ? "file://" + style.notesFolder : ""
        nameFilters: ["*.md"]
        showDirs: false
        onCountChanged: root.refresh()
    }

    ListModel { id: filteredModel }

    function refresh() {
        if (!root.style) return
        _refreshPinned()
        var ids = []
        for (var i = 0; i < folderModel.count; i++) {
            ids.push(folderModel.get(i, "fileName").replace(/\.md$/, ""))
        }
        _loadAll(ids)
    }

    function _loadAll(ids) {
        if (ids.length === 0) { _applyModel([]); return }
        var results = []
        var pending = ids.length
        ids.forEach(function (id) {
            NoteStore.readNote(root.style.shell, root.style.notesFolder, id, function (note) {
                pending--
                if (note) {
                    var title = MarkdownUtils.deriveTitle(note.meta, note.body)
                    results.push({
                        noteId: id,
                        title: title,
                        preview: MarkdownUtils.derivePreview(note.body),
                        modified: note.meta.modified || "",
                        searchBlob: (title + " " + note.body).toLowerCase(),
                        pinned: false
                    })
                }
                if (pending === 0) _applyModel(results)
            })
        })
    }

    function _applyModel(results) {
        results.sort(function (a, b) { return (b.modified || "").localeCompare(a.modified || "") })
        root.allNotes = results
        _applyFilter()
    }

    function _applyFilter() {
        filteredModel.clear()
        var q = root.searchQuery.trim().toLowerCase()
        for (var i = 0; i < root.allNotes.length; i++) {
            var n = root.allNotes[i]
            n.pinned = root.pinnedIds.indexOf(n.noteId) !== -1
            if (q === "" || n.searchBlob.indexOf(q) !== -1) {
                filteredModel.append(n)
            }
        }
    }

    function _refreshPinned() {
        if (!root.style || !root.style.shell) return
        var script = "var out=[]; var ds=desktops(); for (var i=0;i<ds.length;i++){ " +
                      "var ws=ds[i].widgets('net.ownaka.oinknote'); " +
                      "for (var j=0;j<ws.length;j++){ ws[j].currentConfigGroup=['General']; out.push(ws[j].readConfig('noteId')); } } " +
                      "print(out.join(','));"
        var cmd = "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + root.style.shell.quote(script)
        root.style.shell.run(cmd, function (stdout) {
            root.pinnedIds = (stdout || "").trim().split(",").filter(function (s) { return s.length > 0 })
            _applyFilter()
        })
    }

    function togglePin(noteId, isPinned) {
        var script
        if (isPinned) {
            script = "var removed=0; var ds=desktops(); for (var i=0;i<ds.length;i++){ " +
                     "var ws=ds[i].widgets('net.ownaka.oinknote'); " +
                     "for (var j=0;j<ws.length;j++){ ws[j].currentConfigGroup=['General']; " +
                     "if (ws[j].readConfig('noteId')==='" + noteId + "'){ ws[j].remove(); removed++; } } } print(removed);"
        } else {
            script = "var d=desktops()[0]; var w=d.addWidget('net.ownaka.oinknote'); " +
                     "w.currentConfigGroup=['General']; w.writeConfig('noteId','" + noteId + "');"
        }
        var cmd = "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + root.style.shell.quote(script)
        root.style.shell.run(cmd, function () { root._refreshPinned() })
    }

    function requestDelete(noteId) { root.confirmDeleteId = noteId }
    function cancelDelete() { root.confirmDeleteId = "" }
    function confirmDelete() {
        var id = root.confirmDeleteId
        root.confirmDeleteId = ""
        NoteStore.deleteNote(root.style.shell, root.style.notesFolder, id, function () { root.refresh() })
    }

    Component.onCompleted: refresh()
    onStyleChanged: refresh()
    onSearchQueryChanged: _applyFilter()

    Timer {
        interval: 2500
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    Column {
        anchors.fill: parent
        spacing: 0

        Item {
            id: topBar
            width: parent.width
            height: Math.max(novaBtn.implicitHeight, searchField.implicitHeight) + 12

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                OInkButton {
                    id: novaBtn
                    anchors.verticalCenter: parent.verticalCenter
                    text: "[NOVA NOTA]"
                    outlined: true
                    fg: root.style ? root.style.accentColor : "#689d6a"
                    outlineColor: root.style ? root.style.accentColor : "#689d6a"
                    fontFamily: root.style ? root.style.fontFamily : "monospace"
                    onClicked: {
                        NoteStore.createNote(root.style.shell, root.style.notesFolder, function (id) {
                            if (id) root.openNote(id)
                        })
                    }
                }

                QQC.TextField {
                    id: searchField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - novaBtn.width - parent.spacing
                    placeholderText: "[BUSCAR]"
                    color: root.style ? root.style.textColor : "#e6e1d5"
                    placeholderTextColor: root.style ? root.style.dimColor : "#524f46"
                    font.family: root.style ? root.style.fontFamily : "monospace"
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                    background: Rectangle {
                        color: "transparent"
                        border.width: 1
                        border.color: root.style ? root.style.borderColor : "#2e2e2e"
                    }
                    onTextChanged: root.searchQuery = text
                }
            }
        }

        QQC.ScrollView {
            width: parent.width
            height: parent.height - topBar.height
            clip: true

            ListView {
                model: filteredModel
                spacing: 6
                topMargin: 6
                bottomMargin: 6

                delegate: Rectangle {
                    width: ListView.view.width - 12
                    x: 6
                    height: 72
                    color: "transparent"
                    border.color: root.style ? root.style.borderColor : "#2e2e2e"
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: root.openNote(noteId)
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                width: 8
                                height: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pinned
                                color: root.style ? root.style.accentColor : "#689d6a"
                            }

                            Text {
                                width: parent.width - (pinned ? 14 : 0)
                                text: title
                                color: root.style ? root.style.textColor : "#e6e1d5"
                                font.family: root.style ? root.style.fontFamily : "monospace"
                                font.pixelSize: root.style ? root.style.fontSize : 13
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: parent.width
                            text: preview
                            color: root.style ? root.style.secondaryColor : "#888477"
                            font.family: root.style ? root.style.fontFamily : "monospace"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Row {
                            width: parent.width
                            spacing: 6

                            Text {
                                width: parent.width - pinBtn.width - delBtn.width - 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: MarkdownUtils.formatDate(modified)
                                color: root.style ? root.style.dimColor : "#524f46"
                                font.family: root.style ? root.style.fontFamily : "monospace"
                                font.pixelSize: 10
                            }

                            OInkButton {
                                id: pinBtn
                                text: pinned ? "[DESAFIXAR]" : "[FIXAR]"
                                fontPixelSize: 10
                                fg: pinned ? (root.style ? root.style.accentColor : "#689d6a") : (root.style ? root.style.secondaryColor : "#888477")
                                fontFamily: root.style ? root.style.fontFamily : "monospace"
                                onClicked: root.togglePin(noteId, pinned)
                            }

                            OInkButton {
                                id: delBtn
                                text: "[APAGAR]"
                                fontPixelSize: 10
                                fg: root.style ? root.style.secondaryColor : "#888477"
                                fontFamily: root.style ? root.style.fontFamily : "monospace"
                                onClicked: root.requestDelete(noteId)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.confirmDeleteId !== ""
        color: "#000000"
        opacity: 0.6

        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        visible: root.confirmDeleteId !== ""
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 260)
        height: confirmColumn.implicitHeight + 24
        color: root.style ? root.style.bgColor : "#141414"
        border.color: root.style ? root.style.borderColor : "#2e2e2e"
        border.width: 1

        Column {
            id: confirmColumn
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 10

            Text {
                width: parent.width
                text: "[APAGAR ESTA NOTA?]"
                wrapMode: Text.Wrap
                color: root.style ? root.style.textColor : "#e6e1d5"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 12
            }

            Row {
                width: parent.width
                spacing: 8

                OInkButton {
                    text: "[CANCELAR]"
                    fg: root.style ? root.style.secondaryColor : "#888477"
                    fontFamily: root.style ? root.style.fontFamily : "monospace"
                    onClicked: root.cancelDelete()
                }

                OInkButton {
                    text: "[APAGAR]"
                    outlined: true
                    fg: root.style ? root.style.negativeColor : "#b0675f"
                    outlineColor: root.style ? root.style.negativeColor : "#b0675f"
                    fontFamily: root.style ? root.style.fontFamily : "monospace"
                    onClicked: root.confirmDelete()
                }
            }
        }
    }
}
