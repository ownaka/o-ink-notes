.pragma library
.import "MarkdownUtils.js" as MarkdownUtils

// Única fonte de leitura/escrita de notas e configurações, compartilhada
// pelo controlador e por cada widget de nota na área de trabalho.
//
// Leitura e escrita passam pelo ShellRunner (engine "executable" do
// Plasma): QML puro não lê/escreve arquivos arbitrários sozinho (o
// XMLHttpRequest do Qt 6 vem com GET em file:// desligado por padrão,
// e não dá pra pedir pro usuário ligar isso globalmente no plasmashell).
// Conteúdo sempre trafega em base64 pra não ter problema de encoding
// nem de escaping de aspas/cifrão/crase dentro da nota.

function nowIso() {
    return new Date().toISOString()
}

// UUID v4 "na mão": o engine JS do QML (QJSEngine) não expõe
// crypto.randomUUID()/crypto.getRandomValues (não é um navegador), então
// geramos com Math.random(). A entropia (~122 bits) é mais que suficiente
// pra evitar colisão num app local de notas pessoais — bem diferente do
// antigo "n" + Date.now() + 4 dígitos, que podia colidir se duas notas
// fossem criadas no mesmo milissegundo (gerador de IDs que efetivamente
// causava sobrescrita de notas existentes).
function newNoteId() {
    var hex = "0123456789abcdef"
    var uuid = ""
    for (var i = 0; i < 36; i++) {
        if (i === 8 || i === 13 || i === 18 || i === 23) {
            uuid += "-"
        } else if (i === 14) {
            uuid += "4"
        } else if (i === 19) {
            uuid += hex.charAt(8 + Math.floor(Math.random() * 4)) // 8, 9, a ou b
        } else {
            uuid += hex.charAt(Math.floor(Math.random() * 16))
        }
    }
    return "n" + uuid
}

function notePath(notesFolder, id) {
    return notesFolder + "/" + id + ".md"
}

function trashFolder(notesFolder) {
    return notesFolder + "/.lixeira"
}

var TRASH_RETENTION_DAYS = 7

// Diferente do atob()/btoa() de navegador, o Qt.btoa()/Qt.atob() do QML
// já trabalham com UTF-8 diretamente — não precisam (e não devem) passar
// por encodeURIComponent/escape antes.
function utf8ToBase64(text) {
    return Qt.btoa(text)
}

function base64ToUtf8(b64) {
    return Qt.atob(b64)
}

function readTextFile(runner, path, callback) {
    var cmd = "base64 -w0 -- " + runner.quote(path) + " 2>/dev/null"
    runner.run(cmd, function (stdout, exitCode) {
        if (exitCode !== 0 || !stdout) { callback("", false); return }
        try {
            callback(base64ToUtf8(stdout.trim()), true)
        } catch (e) {
            callback("", false)
        }
    })
}

// Grava em arquivo temporário e troca com "mv" (rename é atômico no mesmo
// filesystem): nunca existe uma janela em que o arquivo final está
// parcialmente escrito, mesmo se o processo morrer no meio do caminho.
function writeTextFile(runner, path, text, callback) {
    var dir = path.substring(0, path.lastIndexOf("/"))
    var tmpPath = path + ".tmp" + Date.now() + Math.floor(Math.random() * 100000)
    var b64 = utf8ToBase64(text)
    var cmd = "mkdir -p -- " + runner.quote(dir) +
              " && printf '%s' " + runner.quote(b64) +
              " | base64 -d > " + runner.quote(tmpPath) +
              " && mv -f -- " + runner.quote(tmpPath) + " " + runner.quote(path)
    runner.run(cmd, function (stdout, exitCode) {
        if (callback) callback(exitCode === 0)
    })
}

// Antes de apagar ou sobrescrever um arquivo que já existe, manda a versão
// anterior pra ".lixeira" dentro da pasta de notas (sem erro se o arquivo
// de origem ainda não existir — nota nova não tem o que preservar).
// Depois poda entradas com mais de TRASH_RETENTION_DAYS dias.
function moveToTrash(runner, notesFolder, path, callback) {
    var trash = trashFolder(notesFolder)
    var baseName = path.substring(path.lastIndexOf("/") + 1)
    var trashedPath = trash + "/" + baseName + "." + Date.now()
    var cmd = "mkdir -p -- " + runner.quote(trash) +
              " && if [ -f " + runner.quote(path) + " ]; then" +
              " mv -f -- " + runner.quote(path) + " " + runner.quote(trashedPath) + "; fi" +
              " ; find " + runner.quote(trash) + " -maxdepth 1 -type f -mtime +" + TRASH_RETENTION_DAYS + " -delete 2>/dev/null"
    runner.run(cmd, function (stdout, exitCode) {
        if (callback) callback(exitCode === 0)
    })
}

// --- configurações compartilhadas (settings.json) ---

function defaultSettings(homeDir) {
    return {
        accentColor: "#689d6a",
        fontSize: 13,
        noteOpacity: 0.95,
        showDots: true,
        notesFolder: homeDir + "/.local/share/o-ink-notes/notes",
        importExportFolder: homeDir + "/Documentos/O-Ink Notes"
    }
}

function readSettings(runner, settingsPath, homeDir, callback) {
    var defaults = defaultSettings(homeDir)
    readTextFile(runner, settingsPath, function (text, ok) {
        if (!ok || !text) { callback(defaults); return }
        try {
            var parsed = JSON.parse(text)
            for (var k in defaults) if (!(k in parsed)) parsed[k] = defaults[k]
            callback(parsed)
        } catch (e) {
            callback(defaults)
        }
    })
}

function writeSettings(runner, settingsPath, settings, callback) {
    writeTextFile(runner, settingsPath, JSON.stringify(settings, null, 2), callback)
}

// --- notas ---

function readNote(runner, notesFolder, id, callback) {
    readTextFile(runner, notePath(notesFolder, id), function (raw, ok) {
        if (!ok) { callback(null); return }
        var fm = MarkdownUtils.parseFrontMatter(raw)
        callback({ id: id, meta: fm.meta, body: fm.body })
    })
}

function writeNote(runner, notesFolder, id, meta, body, callback) {
    meta.modified = nowIso()
    var raw = MarkdownUtils.buildFrontMatter(meta, body)
    var path = notePath(notesFolder, id)
    // Preserva a versão anterior na lixeira antes de sobrescrever.
    moveToTrash(runner, notesFolder, path, function () {
        writeTextFile(runner, path, raw, callback)
    })
}

function createNote(runner, notesFolder, callback) {
    var id = newNoteId()
    var now = nowIso()
    var meta = { title: "", created: now, modified: now }
    var body = "# Nova nota\n"
    writeTextFile(runner, notePath(notesFolder, id), MarkdownUtils.buildFrontMatter(meta, body), function (success) {
        // Devolve também o conteúdo que acabou de escrever: quem chamou já
        // sabe exatamente o que está no arquivo, então pode abrir a nota
        // direto sem precisar reler do disco (sem janela de conteúdo
        // antigo "piscando" até a leitura assíncrona terminar).
        callback(success ? id : null, meta, body)
    })
}

function deleteNote(runner, notesFolder, id, callback) {
    moveToTrash(runner, notesFolder, notePath(notesFolder, id), callback)
}

// --- importar / exportar .md avulsos ---

function slugify(title) {
    var s = (title || "nota").toLowerCase()
    var from = "áàâãäéèêëíìîïóòôõöúùûüçñ"
    var to   = "aaaaaeeeeiiiiooooouuuucn"
    for (var i = 0; i < from.length; i++) {
        s = s.split(from.charAt(i)).join(to.charAt(i))
    }
    s = s.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    return s || "nota"
}

function exportNote(runner, note, destFolder, callback) {
    var raw = MarkdownUtils.buildFrontMatter(note.meta, note.body)
    var fileName = slugify(MarkdownUtils.deriveTitle(note.meta, note.body)) + ".md"
    writeTextFile(runner, destFolder + "/" + fileName, raw, function (success) {
        if (callback) callback(success, fileName)
    })
}

function importNoteFromFile(runner, notesFolder, sourcePath, callback) {
    readTextFile(runner, sourcePath, function (raw, ok) {
        if (!ok) { callback(null); return }
        var fm = MarkdownUtils.parseFrontMatter(raw)
        var id = newNoteId()
        var now = nowIso()
        var meta = {
            title: fm.meta.title || MarkdownUtils.deriveTitle(fm.meta, fm.body),
            created: fm.meta.created || now,
            modified: now
        }
        writeTextFile(runner, notePath(notesFolder, id), MarkdownUtils.buildFrontMatter(meta, fm.body), function (success) {
            callback(success ? id : null)
        })
    })
}
