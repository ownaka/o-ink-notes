import QtQuick
import QtQuick.Controls as QQC

// Aba do popup: mesmo texto entre colchetes, com uma linha de destaque
// embaixo quando ativa.
QQC.Button {
    id: root

    property bool active: false
    property color activeColor: "#689d6a"
    property color inactiveColor: "#888477"
    property string fontFamily: "monospace"
    property int fontPixelSize: 11

    flat: true
    topPadding: 6
    bottomPadding: 6
    implicitHeight: Math.ceil(fontPixelSize * 1.8) + topPadding + bottomPadding

    background: Rectangle {
        color: "transparent"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.active ? 2 : 0
            color: root.activeColor
        }
    }

    contentItem: Text {
        text: root.text
        color: root.active ? root.activeColor : root.inactiveColor
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
