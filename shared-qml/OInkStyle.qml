import QtQuick
import Qt.labs.platform as Labs
import "NoteStore.js" as NoteStore

// Guarda a paleta fixa do tema O-Ink e as opções compartilhadas
// (settings.json), relidas periodicamente para que todas as notas
// fixadas na área de trabalho reajam quando o popup muda alguma opção.
Item {
    id: root

    property var shell: null // ShellRunner, setado por quem instancia

    readonly property string homeDir: _urlToPath(Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation))
    readonly property string settingsPath: homeDir + "/.config/o-ink-notes/settings.json"

    property string accentColor: "#689d6a"
    property int fontSize: 13
    property real noteOpacity: 0.95
    property bool showDots: true
    property string notesFolder: homeDir + "/.local/share/o-ink-notes/notes"
    property string importExportFolder: homeDir + "/Documentos/O-Ink Notes"

    readonly property string bgColor: "#141414"
    readonly property string borderColor: "#2e2e2e"
    readonly property string textColor: "#e6e1d5"
    readonly property string secondaryColor: "#888477"
    readonly property string dimColor: "#524f46"
    readonly property string negativeColor: "#b0675f"
    readonly property string fontFamily: "Commit Mono"

    signal loaded()

    function _urlToPath(url) {
        return url.toString().replace(/^file:\/\//, "")
    }

    function reload() {
        if (!root.shell) return
        NoteStore.readSettings(root.shell, settingsPath, homeDir, function (s) {
            root.accentColor = s.accentColor
            root.fontSize = s.fontSize
            root.noteOpacity = s.noteOpacity
            root.showDots = s.showDots
            root.notesFolder = s.notesFolder
            root.importExportFolder = s.importExportFolder
            root.loaded()
        })
    }

    function save() {
        if (!root.shell) return
        NoteStore.writeSettings(root.shell, root.settingsPath, {
            accentColor: root.accentColor,
            fontSize: root.fontSize,
            noteOpacity: root.noteOpacity,
            showDots: root.showDots,
            notesFolder: root.notesFolder,
            importExportFolder: root.importExportFolder
        }, function () {})
    }

    Component.onCompleted: reload()

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.reload()
    }
}
