import QtQuick
import QtQuick.Controls as QQC
import "MarkdownUtils.js" as MarkdownUtils
import "NoteStore.js" as NoteStore

// Mostra uma nota renderizada (markdown + checkboxes de tarefa); um
// clique entra em modo de edição (textarea cru); ao perder o foco,
// salva e volta a mostrar renderizado. Usado tanto no popup quanto no
// widget de nota fixado na área de trabalho.
Item {
    id: root

    property var style
    property string noteId: ""
    property var meta: ({ title: "", created: "", modified: "" })
    property string bodyText: ""
    property bool editing: false
    property bool ready: false

    readonly property var blocks: MarkdownUtils.parseBlocks(bodyText)
    property string _pendingLoadId: ""

    function load(id) {
        root.noteId = id
        root.ready = false
        if (!id || !style) { root._pendingLoadId = id; return }
        root._pendingLoadId = ""
        NoteStore.readNote(style.shell, style.notesFolder, id, function (note) {
            if (!note) return
            root.meta = note.meta
            root.bodyText = note.body
            root.ready = true
        })
    }

    onStyleChanged: if (root._pendingLoadId) load(root._pendingLoadId)

    function save() {
        if (!root.noteId || !style || !style.shell) return
        NoteStore.writeNote(style.shell, style.notesFolder, root.noteId, root.meta, root.bodyText, function () {})
    }

    function toggleTask(lineIndex) {
        root.bodyText = MarkdownUtils.toggleTask(root.bodyText, lineIndex)
        root.save()
    }

    function startEditing() {
        editArea.text = root.bodyText
        root.editing = true
        editArea.forceActiveFocus()
    }

    function stopEditingAndSave() {
        if (!root.editing) return
        root.editing = false
        root.bodyText = editArea.text
        root.save()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        visible: !root.editing
        contentWidth: width
        contentHeight: viewColumn.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        MouseArea {
            width: flick.width
            height: Math.max(flick.height, viewColumn.implicitHeight + 20)
            onClicked: root.startEditing()
            z: -1
        }

        Column {
            id: viewColumn
            x: 10
            y: 10
            width: flick.width - 20
            spacing: 4

            Repeater {
                model: root.blocks

                delegate: Item {
                    width: viewColumn.width
                    height: blockData.type === "task" ? taskLine.height : mdText.contentHeight

                    property var blockData: modelData

                    Text {
                        id: mdText
                        visible: blockData.type === "md"
                        width: parent.width
                        text: blockData.type === "md" ? blockData.text : ""
                        textFormat: Text.MarkdownText
                        wrapMode: Text.Wrap
                        color: root.style ? root.style.textColor : "#e6e1d5"
                        linkColor: root.style ? root.style.accentColor : "#689d6a"
                        font.family: root.style ? root.style.fontFamily : "monospace"
                        font.pixelSize: root.style ? root.style.fontSize : 13
                    }

                    TaskLine {
                        id: taskLine
                        visible: blockData.type === "task"
                        width: parent.width
                        checked: blockData.type === "task" ? blockData.checked : false
                        labelText: blockData.type === "task" ? blockData.text : ""
                        accentColor: root.style ? root.style.accentColor : "#689d6a"
                        textColor: root.style ? root.style.textColor : "#e6e1d5"
                        fontFamily: root.style ? root.style.fontFamily : "monospace"
                        fontPixelSize: root.style ? root.style.fontSize : 13
                        onToggled: root.toggleTask(blockData.line)
                    }
                }
            }
        }
    }

    QQC.TextArea {
        id: editArea
        anchors.fill: parent
        visible: root.editing
        wrapMode: QQC.TextArea.Wrap
        selectByMouse: true
        color: root.style ? root.style.textColor : "#e6e1d5"
        font.family: root.style ? root.style.fontFamily : "monospace"
        font.pixelSize: root.style ? root.style.fontSize : 13
        background: Rectangle { color: "transparent" }

        onActiveFocusChanged: if (!activeFocus) root.stopEditingAndSave()
    }
}
