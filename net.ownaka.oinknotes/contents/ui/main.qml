import QtQuick
import QtQuick.Controls as QQC
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "shared"

PlasmoidItem {
    id: controllerRoot

    Plasmoid.icon: "o-ink-notes"

    // Incrementado pelo menu de contexto (botão direito no ícone): recarrega
    // as configurações do disco e força a lista de notas a reler tudo da
    // pasta, sem precisar reiniciar o plasmashell inteiro.
    property int syncRequestId: 0

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "[SINCRONIZAR NOTAS]"
            icon.name: "view-refresh"
            onTriggered: {
                oinkStyle.reload()
                controllerRoot.syncRequestId++
            }
        }
    ]

    ShellRunner { id: shellRunner }
    OInkStyle { id: oinkStyle; shell: shellRunner }

    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: 2
            source: "o-ink-notes"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: controllerRoot.expanded = !controllerRoot.expanded
        }
    }

    fullRepresentation: Item {
        id: popup
        implicitWidth: 360
        implicitHeight: 460

        property string page: "list"
        property string currentNoteId: ""
        property var currentNotePreloaded: null

        Rectangle {
            anchors.fill: parent
            color: oinkStyle.bgColor
            border.color: oinkStyle.borderColor
            border.width: 1

            DotsBackground {
                anchors.fill: parent
                anchors.margins: 1
                visible: oinkStyle.showDots
                dotColor: oinkStyle.borderColor
            }

            Column {
                anchors.fill: parent
                spacing: 0

                Row {
                    id: tabs
                    width: parent.width

                    OInkTabButton {
                        width: tabs.width / 3
                        text: "[NOTAS]"
                        active: popup.page === "list" || popup.page === "editor"
                        activeColor: oinkStyle.accentColor
                        inactiveColor: oinkStyle.secondaryColor
                        fontFamily: oinkStyle.fontFamily
                        onClicked: popup.page = "list"
                    }

                    OInkTabButton {
                        width: tabs.width / 3
                        text: "[CONFIG]"
                        active: popup.page === "settings"
                        activeColor: oinkStyle.accentColor
                        inactiveColor: oinkStyle.secondaryColor
                        fontFamily: oinkStyle.fontFamily
                        onClicked: popup.page = "settings"
                    }

                    OInkTabButton {
                        width: tabs.width / 3
                        text: "[ARQUIVOS]"
                        active: popup.page === "importexport"
                        activeColor: oinkStyle.accentColor
                        inactiveColor: oinkStyle.secondaryColor
                        fontFamily: oinkStyle.fontFamily
                        onClicked: popup.page = "importexport"
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - tabs.height

                    NotesListPage {
                        anchors.fill: parent
                        visible: popup.page === "list"
                        style: oinkStyle
                        syncTrigger: controllerRoot.syncRequestId
                        onOpenNote: (id, preloaded) => {
                            popup.currentNoteId = id
                            popup.currentNotePreloaded = preloaded
                            popup.page = "editor"
                        }
                    }

                    Item {
                        id: editorPage
                        anchors.fill: parent
                        visible: popup.page === "editor"

                        // Carrega ao entrar; fecha (salva se mudou algo e
                        // sai do modo de edição) ao sair — não importa se a
                        // saída foi pelo [VOLTAR] ou trocando de aba.
                        onVisibleChanged: {
                            if (visible) {
                                editorView.load(popup.currentNoteId, popup.currentNotePreloaded)
                                popup.currentNotePreloaded = null
                            } else {
                                editorView.closeEditor()
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            OInkButton {
                                id: backButton
                                text: "[VOLTAR]"
                                fg: oinkStyle.secondaryColor
                                fontFamily: oinkStyle.fontFamily
                                onClicked: popup.page = "list"
                            }

                            NoteView {
                                id: editorView
                                width: parent.width
                                height: parent.height - backButton.height - 4
                                style: oinkStyle
                            }
                        }
                    }

                    SettingsPage {
                        anchors.fill: parent
                        visible: popup.page === "settings"
                        style: oinkStyle
                    }

                    ImportExportPage {
                        anchors.fill: parent
                        visible: popup.page === "importexport"
                        style: oinkStyle
                    }
                }
            }
        }
    }
}
