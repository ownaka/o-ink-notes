import QtQuick
import QtQuick.Controls as QQC
import "shared"

Item {
    id: root
    property var style

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: "[COR DE DESTAQUE]"
                color: root.style ? root.style.secondaryColor : "#888477"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
            }
            Row {
                spacing: 6
                Repeater {
                    model: ["#689d6a", "#b0675f", "#b89a5e", "#888477", "#e6e1d5"]
                    delegate: Rectangle {
                        width: 22
                        height: 22
                        color: modelData
                        border.width: root.style && root.style.accentColor === modelData ? 2 : 1
                        border.color: root.style ? root.style.textColor : "#e6e1d5"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.style.accentColor = modelData
                                root.style.save()
                            }
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: "[TAMANHO DA FONTE] " + (root.style ? root.style.fontSize : 13)
                color: root.style ? root.style.secondaryColor : "#888477"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
            }
            QQC.Slider {
                width: parent.width
                from: 10
                to: 20
                stepSize: 1
                value: root.style ? root.style.fontSize : 13
                onMoved: {
                    root.style.fontSize = Math.round(value)
                    root.style.save()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: "[OPACIDADE DAS NOTAS] " + (root.style ? Math.round(root.style.noteOpacity * 100) : 95) + "%"
                color: root.style ? root.style.secondaryColor : "#888477"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
            }
            QQC.Slider {
                width: parent.width
                from: 0.4
                to: 1.0
                stepSize: 0.05
                value: root.style ? root.style.noteOpacity : 0.95
                onMoved: {
                    root.style.noteOpacity = value
                    root.style.save()
                }
            }
        }

        Row {
            spacing: 8
            QQC.CheckBox {
                checked: root.style ? root.style.showDots : true
                onToggled: {
                    root.style.showDots = checked
                    root.style.save()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "[MOSTRAR PONTINHOS DE FUNDO]"
                color: root.style ? root.style.textColor : "#e6e1d5"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: "[PASTA DAS NOTAS]"
                color: root.style ? root.style.secondaryColor : "#888477"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
            }
            QQC.TextField {
                width: parent.width
                text: root.style ? root.style.notesFolder : ""
                color: root.style ? root.style.textColor : "#e6e1d5"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    color: "transparent"
                    border.color: root.style ? root.style.borderColor : "#2e2e2e"
                    border.width: 1
                }
                onEditingFinished: {
                    root.style.notesFolder = text
                    root.style.save()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: "[PASTA DE IMPORTAR/EXPORTAR]"
                color: root.style ? root.style.secondaryColor : "#888477"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
            }
            QQC.TextField {
                width: parent.width
                text: root.style ? root.style.importExportFolder : ""
                color: root.style ? root.style.textColor : "#e6e1d5"
                font.family: root.style ? root.style.fontFamily : "monospace"
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    color: "transparent"
                    border.color: root.style ? root.style.borderColor : "#2e2e2e"
                    border.width: 1
                }
                onEditingFinished: {
                    root.style.importExportFolder = text
                    root.style.save()
                }
            }
        }
    }
}
