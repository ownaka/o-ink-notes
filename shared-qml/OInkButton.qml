import QtQuick
import QtQuick.Controls as QQC

// Botão de texto entre colchetes, no estilo do tema: fundo transparente,
// borda reta opcional, texto sempre centralizado (horizontal e vertical)
// e altura calculada a partir da fonte, pra nunca cortar ascendentes
// nem descendentes do Commit Mono.
QQC.Button {
    id: root

    property color fg: "#e6e1d5"
    property bool outlined: false
    property color outlineColor: fg
    property string fontFamily: "monospace"
    property int fontPixelSize: 11

    flat: true
    topPadding: 6
    bottomPadding: 6
    leftPadding: 10
    rightPadding: 10
    implicitHeight: Math.ceil(fontPixelSize * 1.8) + topPadding + bottomPadding

    background: Rectangle {
        color: "transparent"
        border.width: root.outlined ? 1 : 0
        border.color: root.outlineColor
    }

    contentItem: Text {
        text: root.text
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
