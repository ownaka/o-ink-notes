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
    // Incrementado a cada load(): uma leitura assíncrona que termina depois
    // de um load() mais novo (ex. trocou de nota rápido) é descartada em
    // vez de pisar no conteúdo da nota atual com o de uma nota antiga.
    property int _loadToken: 0

    // "preloaded" (opcional): { meta, body } já conhecidos por quem chamou
    // (ex. acabou de criar a nota) — pula a leitura assíncrona, então não
    // existe nem uma fração de segundo em que a tela mostra o conteúdo da
    // nota anterior por engano.
    function load(id, preloaded) {
        // Antes de trocar de nota, fecha a edição da nota ANTERIOR (salva
        // se mudou algo) com o id/estado ainda antigos. Sem isso, um
        // fechamento tardio (ex. perda de foco disparada depois da troca)
        // gravaria o texto da nota antiga no arquivo da nota nova.
        root.closeEditor()

        root.noteId = id
        root.ready = false
        // Limpa o conteúdo na hora: enquanto a leitura não termina, a tela
        // não pode continuar mostrando o texto da nota anterior.
        root.meta = { title: "", created: "", modified: "" }
        root.bodyText = ""
        root._loadToken++
        var token = root._loadToken
        if (!id || !style) { root._pendingLoadId = id; return }
        root._pendingLoadId = ""

        if (preloaded) {
            root.meta = preloaded.meta
            root.bodyText = preloaded.body
            root.ready = true
            return
        }

        NoteStore.readNote(style.shell, style.notesFolder, id, function (note) {
            if (token !== root._loadToken) return // leitura de um load() já superado
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
        if (!root.ready) return // não deixa editar antes do conteúdo real ter chegado
        editArea.text = root.bodyText
        root.editing = true
        editArea.forceActiveFocus()
    }

    // Sai do modo de edição (volta a mostrar renderizado) e só grava se o
    // texto realmente mudou desde que a edição começou.
    function closeEditor() {
        if (!root.editing) return
        root.editing = false
        if (editArea.text !== root.bodyText) {
            root.bodyText = editArea.text
            root.save()
        }
    }

    // Mostra sempre qual nota está aberta (e se já carregou de verdade),
    // pra nunca ficar na dúvida se o que está na tela é a nota certa.
    Text {
        id: statusLabel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        text: root.ready
              ? ("[" + (MarkdownUtils.deriveTitle(root.meta, root.bodyText) || "SEM TÍTULO") + "]")
              : "[CARREGANDO…]"
        elide: Text.ElideRight
        color: root.style ? root.style.secondaryColor : "#888477"
        font.family: root.style ? root.style.fontFamily : "monospace"
        font.pixelSize: Math.max(9, (root.style ? root.style.fontSize : 13) - 4)
    }

    Flickable {
        id: flick
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
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
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        visible: root.editing
        wrapMode: QQC.TextArea.Wrap
        selectByMouse: true
        color: root.style ? root.style.textColor : "#e6e1d5"
        font.family: root.style ? root.style.fontFamily : "monospace"
        font.pixelSize: root.style ? root.style.fontSize : 13
        background: Rectangle { color: "transparent" }

        onActiveFocusChanged: if (!activeFocus) root.closeEditor()
    }
}
