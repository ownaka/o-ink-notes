import QtQuick
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel
import "shared"
import "shared/NoteStore.js" as NoteStore
import "shared/MarkdownUtils.js" as MarkdownUtils

Item {
    id: root

    property var style
    property string status: ""

    FolderListModel {
        id: notesFolderModel
        folder: style && style.notesFolder ? "file://" + style.notesFolder : ""
        nameFilters: ["*.md"]
        showDirs: false
    }

    FolderListModel {
        id: importFolderModel
        folder: style && style.importExportFolder ? "file://" + style.importExportFolder : ""
        nameFilters: ["*.md"]
        showDirs: false
    }

    function exportAll() {
        var pending = notesFolderModel.count
        if (pending === 0) { root.status = "Nenhuma nota pra exportar."; return }
        root.status = "Exportando " + pending + " nota(s)…"
        var done = 0
        for (var i = 0; i < notesFolderModel.count; i++) {
            var id = notesFolderModel.get(i, "fileName").replace(/\.md$/, "")
            NoteStore.readNote(style.shell, style.notesFolder, id, function (note) {
                if (note) {
                    NoteStore.exportNote(style.shell, note, style.importExportFolder, function () {
                        done++
                        if (done >= pending) root.status = "Exportado(s) " + done + " arquivo(s) em " + style.importExportFolder
                    })
                } else {
                    done++
                }
            })
        }
    }

    function importFile(fileName) {
        var path = style.importExportFolder + "/" + fileName
        NoteStore.importNoteFromFile(style.shell, style.notesFolder, path, function (id) {
            root.status = id ? "Importado: " + fileName : "Falha ao importar " + fileName
        })
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        OInkButton {
            text: "[EXPORTAR TODAS AS NOTAS]"
            outlined: true
            fg: root.style ? root.style.accentColor : "#689d6a"
            outlineColor: root.style ? root.style.accentColor : "#689d6a"
            fontFamily: root.style ? root.style.fontFamily : "monospace"
            onClicked: root.exportAll()
        }

        Text {
            text: "[IMPORTAR DE: " + (root.style ? root.style.importExportFolder : "") + "]"
            color: root.style ? root.style.secondaryColor : "#888477"
            font.family: root.style ? root.style.fontFamily : "monospace"
            font.pixelSize: 11
            wrapMode: Text.Wrap
            width: parent.width
        }

        QQC.ScrollView {
            width: parent.width
            height: parent.height - 120
            clip: true

            ListView {
                model: importFolderModel
                spacing: 1

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 36
                    color: "transparent"
                    border.width: 1
                    border.color: root.style ? root.style.borderColor : "#2e2e2e"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Text {
                            width: parent.width - 90
                            anchors.verticalCenter: parent.verticalCenter
                            text: fileName
                            color: root.style ? root.style.textColor : "#e6e1d5"
                            font.family: root.style ? root.style.fontFamily : "monospace"
                            font.pixelSize: root.style ? root.style.fontSize : 13
                            elide: Text.ElideRight
                        }

                        OInkButton {
                            text: "[IMPORTAR]"
                            fontPixelSize: 10
                            fg: root.style ? root.style.secondaryColor : "#888477"
                            fontFamily: root.style ? root.style.fontFamily : "monospace"
                            onClicked: root.importFile(fileName)
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            text: root.status
            wrapMode: Text.Wrap
            color: root.style ? root.style.secondaryColor : "#888477"
            font.family: root.style ? root.style.fontFamily : "monospace"
            font.pixelSize: 11
        }
    }
}
