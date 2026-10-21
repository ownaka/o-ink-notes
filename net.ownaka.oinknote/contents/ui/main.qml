import QtQuick
import org.kde.plasma.plasmoid
import "shared"

PlasmoidItem {
    id: noteRoot

    width: 240
    height: 220

    ShellRunner { id: shellRunner }
    OInkStyle { id: oinkStyle; shell: shellRunner }

    function _loadConfiguredNote() {
        if (Plasmoid.configuration.noteId) {
            noteView.load(Plasmoid.configuration.noteId)
        }
    }

    Component.onCompleted: _loadConfiguredNote()

    Connections {
        target: Plasmoid.configuration
        function onNoteIdChanged() { noteRoot._loadConfiguredNote() }
    }

    Rectangle {
        anchors.fill: parent
        color: oinkStyle.bgColor
        opacity: oinkStyle.noteOpacity
        border.color: oinkStyle.borderColor
        border.width: 1
        radius: 0

        DotsBackground {
            anchors.fill: parent
            anchors.margins: 1
            visible: oinkStyle.showDots
            dotColor: oinkStyle.borderColor
        }

        Text {
            id: label
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 6
            text: "[NOTA]"
            color: oinkStyle.secondaryColor
            font.family: oinkStyle.fontFamily
            font.pixelSize: Math.max(9, oinkStyle.fontSize - 3)
        }

        NoteView {
            id: noteView
            anchors.top: label.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            style: oinkStyle
        }
    }
}
