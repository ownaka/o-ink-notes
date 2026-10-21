import QtQuick

// Uma linha "- [ ] texto" / "- [x] texto" renderizada como checkbox +
// texto clicável (o Text.MarkdownText do Qt não faz isso sozinho).
Row {
    id: root

    property bool checked: false
    property string labelText: ""
    property color accentColor: "#689d6a"
    property color textColor: "#e6e1d5"
    property string fontFamily: "Commit Mono"
    property int fontPixelSize: 13

    signal toggled()

    spacing: 8
    height: Math.max(box.height, label.implicitHeight)

    Rectangle {
        id: box
        width: root.fontPixelSize
        height: root.fontPixelSize
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? root.accentColor : "transparent"
        border.color: root.accentColor
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggled()
        }
    }

    Text {
        id: label
        width: root.width - box.width - root.spacing
        text: root.labelText
        textFormat: Text.MarkdownText
        wrapMode: Text.Wrap
        color: root.textColor
        opacity: root.checked ? 0.6 : 1.0
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.strikeout: root.checked

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggled()
        }
    }
}
