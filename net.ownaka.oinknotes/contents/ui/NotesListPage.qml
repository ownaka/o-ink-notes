import QtQuick
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel
import "shared"
import "shared/NoteStore.js" as NoteStore
import "shared/MarkdownUtils.js" as MarkdownUtils

Item {
    id: root

    property var style
    // "preloaded" vem preenchido só na criação de nota nova (já sabemos o
    // conteúdo, sem precisar reler do disco); null quando é nota existente.
    signal openNote(string id, var preloaded)

    // Muda quando o usuário clica em "[SINCRONIZAR NOTAS]" no menu de
    // contexto do ícone (botão direito) — força reler tudo da pasta.
    property int syncTrigger: 0
    onSyncTriggerChanged: refresh()

    property string searchQuery: ""
    property var pinnedIds: []
    property var allNotes: []
    property string confirmDeleteId: ""
    property bool creatingNote: false
    // Incrementado a cada refresh(): descarta o resultado de uma
    // atualização mais antiga que termine depois de uma mais nova (evita
    // notas duplicadas/estado velho quando o timer e um refresh manual
    // ficam em voo ao mesmo tempo).
    property int _refreshGeneration: 0

    // Cada refresh() reler nota por nota (um processo novo por nota, via
    // ShellRunner) é o que deixava o Plasma inteiro lento: com N notas
    // visíveis, isso é N processos por segundo, pra sempre, enquanto o
    // popup estiver aberto. O FolderListModel já expõe fileModified sem
    // custo (é só stat, ele mesmo observa a pasta); guardando o último
    // fileModified visto por nota, só relemos (só gastamos um processo)
    // a nota que realmente mudou desde o ciclo anterior.
    property var _mtimeCache: ({})
    property var _entryCache: ({})

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
        root._refreshGeneration++
        var generation = root._refreshGeneration
        var items = []
        var liveIds = ({})
        for (var i = 0; i < folderModel.count; i++) {
            var id = folderModel.get(i, "fileName").replace(/\.md$/, "")
            var modified = folderModel.get(i, "fileModified")
            items.push({ id: id, mtime: modified ? modified.getTime() : 0 })
            liveIds[id] = true
        }
        // Descarta cache de notas apagadas, pra não crescer pra sempre.
        for (var cachedId in root._entryCache) {
            if (!liveIds[cachedId]) {
                delete root._entryCache[cachedId]
                delete root._mtimeCache[cachedId]
            }
        }
        _loadAll(items, generation)
    }

    function _loadAll(items, generation) {
        if (items.length === 0) { _applyModel([], generation); return }
        var results = []
        var toRead = []
        items.forEach(function (item) {
            var cached = root._entryCache[item.id]
            if (cached && root._mtimeCache[item.id] === item.mtime) {
                results.push(cached)
            } else {
                toRead.push(item)
            }
        })
        if (toRead.length === 0) { _applyModel(results, generation); return }
        var pending = toRead.length
        toRead.forEach(function (item) {
            NoteStore.readNote(root.style.shell, root.style.notesFolder, item.id, function (note) {
                pending--
                if (note) {
                    var title = MarkdownUtils.deriveTitle(note.meta, note.body)
                    var entry = {
                        noteId: item.id,
                        title: title,
                        preview: MarkdownUtils.derivePreview(note.body),
                        modified: note.meta.modified || "",
                        searchBlob: (title + " " + note.body).toLowerCase(),
                        pinned: false
                    }
                    root._entryCache[item.id] = entry
                    root._mtimeCache[item.id] = item.mtime
                    results.push(entry)
                }
                if (pending === 0) _applyModel(results, generation)
            })
        })
    }

    function _applyModel(results, generation) {
        if (generation !== root._refreshGeneration) return // refresh() mais velho, descarta
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
    onVisibleChanged: if (visible) refresh()

    // Não existe file watcher no QML puro (sem plugin C++), então a pasta
    // de notas é a fonte de verdade e esse timer é como o popup percebe
    // mudanças feitas por fora (ex. editadas pelo widget da área de
    // trabalho, outro processo). 1s é rápido o bastante pra parecer "quase
    // na hora" sem martelar o shell com muitos processos por segundo.
    Timer {
        interval: 1000
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
                    enabled: !root.creatingNote
                    onClicked: {
                        if (root.creatingNote) return // trava contra duplo-clique criando 2 notas
                        root.creatingNote = true
                        NoteStore.createNote(root.style.shell, root.style.notesFolder, function (id, meta, body) {
                            root.creatingNote = false
                            if (id) root.openNote(id, { meta: meta, body: body })
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
                        onClicked: root.openNote(noteId, null)
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
