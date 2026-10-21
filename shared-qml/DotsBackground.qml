import QtQuick

// Fundo de pontinhos bem sutil, opcional (liga/desliga pela opção
// "showDots" do popup). Desenhado em Canvas pra não precisar de um
// Repeater gigante quando a nota é grande.
Item {
    id: root

    property color dotColor: "#2e2e2e"
    property real spacing: 18
    property real dotSize: 1.2

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.dotColor
            for (var x = root.spacing / 2; x < width; x += root.spacing) {
                for (var y = root.spacing / 2; y < height; y += root.spacing) {
                    ctx.beginPath()
                    ctx.arc(x, y, root.dotSize, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onDotColorChanged: canvas.requestPaint()
}
