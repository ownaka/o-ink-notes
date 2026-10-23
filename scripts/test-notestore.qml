// Teste rápido do NoteStore (camada de arquivo): cria várias notas em
// sequência rápida, edita, apaga, e confere que nada foi sobrescrito ou
// duplicado. Roda isolado numa pasta temporária — nunca toca nas notas
// reais do usuário.
//
// Uso: qml6 scripts/test-notestore.qml
// Sai com código 0 se tudo passar, 1 se algo falhar (olhe o [FALHA] no log).

import QtQuick
import "../shared-qml" as Shared
import "../shared-qml/NoteStore.js" as NoteStore

Item {
    id: root

    property int failures: 0
    property string notesFolder: "/tmp/o-ink-notes-test-" + Date.now()

    function check(cond, label) {
        if (cond) {
            console.log("[ok]    " + label)
        } else {
            console.log("[FALHA] " + label)
            root.failures++
        }
    }

    Shared.ShellRunner { id: shell }

    function listMdFiles(dir, callback) {
        shell.run("ls -1 -- " + shell.quote(dir) + " 2>/dev/null | grep '\\.md$' || true", function (stdout) {
            var names = (stdout || "").split("\n").filter(function (s) { return s.length > 0 })
            callback(names)
        })
    }

    function countFiles(dir, callback) {
        shell.run("find " + shell.quote(dir) + " -maxdepth 1 -type f 2>/dev/null | wc -l", function (stdout) {
            callback(parseInt((stdout || "0").trim(), 10))
        })
    }

    function finish() {
        console.log("")
        if (root.failures === 0) {
            console.log("Todos os testes passaram.")
        } else {
            console.log(root.failures + " teste(s) falharam.")
        }
        shell.run("rm -rf -- " + shell.quote(root.notesFolder), function () {
            Qt.exit(root.failures === 0 ? 0 : 1)
        })
    }

    function step1_createManyConcurrently() {
        console.log("== Passo 1: criar 10 notas em sequência rápida (sem esperar uma terminar) ==")
        var ids = []
        var pending = 10
        for (var i = 0; i < 10; i++) {
            NoteStore.createNote(shell, root.notesFolder, function (id) {
                check(id !== null, "createNote retornou um id")
                if (id) ids.push(id)
                pending--
                if (pending === 0) {
                    check((new Set(ids)).size === ids.length, "todos os 10 ids são únicos")
                    listMdFiles(root.notesFolder, function (files) {
                        check(files.length === 10, "existem exatamente 10 arquivos .md (achou " + files.length + ")")
                        root._createdIds = ids
                        step2_editOneAndCheckTrash()
                    })
                }
            })
        }
    }

    property var _createdIds: []

    function step2_editOneAndCheckTrash() {
        console.log("== Passo 2: editar uma nota existente (deve ir pra .lixeira a versão antiga) ==")
        var id = root._createdIds[0]
        NoteStore.readNote(shell, root.notesFolder, id, function (noteBefore) {
            check(noteBefore !== null, "leu a nota antes de editar")
            NoteStore.writeNote(shell, root.notesFolder, id, noteBefore.meta, "# Editada\nconteúdo novo", function (ok) {
                check(ok, "writeNote reportou sucesso")
                NoteStore.readNote(shell, root.notesFolder, id, function (noteAfter) {
                    check(noteAfter.body.indexOf("Editada") !== -1, "conteúdo novo foi gravado")
                    listMdFiles(root.notesFolder, function (files) {
                        check(files.length === 10, "continuam exatamente 10 notas (nenhuma duplicada)")
                        // confere as outras 9 notas continuam intactas (não sobrescritas)
                        var others = root._createdIds.filter(function (x) { return x !== id })
                        var checkedCount = 0
                        others.forEach(function (otherId) {
                            NoteStore.readNote(shell, root.notesFolder, otherId, function (note) {
                                check(note !== null && note.body.indexOf("Nova nota") !== -1,
                                      "nota " + otherId + " não foi afetada pela edição de outra nota")
                                checkedCount++
                                if (checkedCount === others.length) {
                                    countFiles(root.notesFolder + "/.lixeira", function (count) {
                                        check(count >= 1, "versão anterior foi preservada em .lixeira (" + count + " arquivo(s))")
                                        step3_delete()
                                    })
                                }
                            })
                        })
                    })
                })
            })
        })
    }

    function step3_delete() {
        console.log("== Passo 3: apagar uma nota (deve mover pra .lixeira, não sumir de vez) ==")
        var id = root._createdIds[1]
        NoteStore.deleteNote(shell, root.notesFolder, id, function (ok) {
            check(ok, "deleteNote reportou sucesso")
            NoteStore.readNote(shell, root.notesFolder, id, function (note) {
                check(note === null, "nota apagada não é mais lida na pasta principal")
                listMdFiles(root.notesFolder, function (files) {
                    check(files.length === 9, "sobraram exatamente 9 notas na pasta principal")
                    countFiles(root.notesFolder + "/.lixeira", function (count) {
                        check(count >= 2, "a nota apagada também foi preservada em .lixeira (" + count + " arquivo(s) no total)")
                        finish()
                    })
                })
            })
        })
    }

    Component.onCompleted: {
        console.log("Pasta de teste (isolada, não é a pasta real de notas): " + notesFolder)
        step1_createManyConcurrently()
    }
}
