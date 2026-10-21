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

function newNoteId() {
    return "n" + Date.now() + Math.floor(1000 + Math.random() * 9000)
}

function notePath(notesFolder, id) {
    return notesFolder + "/" + id + ".md"
}

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

function writeTextFile(runner, path, text, callback) {
    var dir = path.substring(0, path.lastIndexOf("/"))
    var b64 = utf8ToBase64(text)
    var cmd = "mkdir -p -- " + runner.quote(dir) +
              " && printf '%s' " + runner.quote(b64) +
              " | base64 -d > " + runner.quote(path)
    runner.run(cmd, function (stdout, exitCode) {
        if (callback) callback(exitCode === 0)
    })
}

function deleteFile(runner, path, callback) {
    runner.run("rm -f -- " + runner.quote(path), function (stdout, exitCode) {
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
    writeTextFile(runner, notePath(notesFolder, id), raw, callback)
}

function createNote(runner, notesFolder, callback) {
    var id = newNoteId()
    var now = nowIso()
    var meta = { title: "", created: now, modified: now }
    var body = "# Nova nota\n"
    writeTextFile(runner, notePath(notesFolder, id), MarkdownUtils.buildFrontMatter(meta, body), function (success) {
        callback(success ? id : null)
    })
}

function deleteNote(runner, notesFolder, id, callback) {
    deleteFile(runner, notePath(notesFolder, id), callback)
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
