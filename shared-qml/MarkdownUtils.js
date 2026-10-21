.pragma library

// Qt.MarkdownText (Text.MarkdownText) não renderiza lista de tarefas como
// checkbox clicável — só mostra o "[ ]" literal. Por isso separamos as
// linhas "- [ ] algo" do resto do markdown, que continua indo inteiro pro
// Text normal (títulos, negrito, itálico, listas, código, links).

var TASK_RE = /^(\s*)-\s\[([ xX])\]\s(.*)$/

function parseBlocks(text) {
    var lines = (text || "").split("\n")
    var blocks = []
    var mdBuffer = []

    function flushMd() {
        if (mdBuffer.length > 0) {
            blocks.push({ type: "md", text: mdBuffer.join("\n") })
            mdBuffer = []
        }
    }

    for (var i = 0; i < lines.length; i++) {
        var m = TASK_RE.exec(lines[i])
        if (m) {
            flushMd()
            blocks.push({
                type: "task",
                line: i,
                indent: m[1],
                checked: m[2].toLowerCase() === "x",
                text: m[3]
            })
        } else {
            mdBuffer.push(lines[i])
        }
    }
    flushMd()
    return blocks
}

function toggleTask(text, lineIndex) {
    var lines = (text || "").split("\n")
    if (lineIndex < 0 || lineIndex >= lines.length) return text
    var m = TASK_RE.exec(lines[lineIndex])
    if (!m) return text
    var newMark = m[2].trim() === "" ? "x" : " "
    lines[lineIndex] = m[1] + "- [" + newMark + "] " + m[3]
    return lines.join("\n")
}

// --- front-matter simples (chave: valor), sem precisar de parser YAML ---

function parseFrontMatter(raw) {
    raw = raw || ""
    var meta = {}
    if (raw.indexOf("---\n") === 0) {
        var end = raw.indexOf("\n---\n", 4)
        if (end !== -1) {
            var header = raw.substring(4, end)
            var body = raw.substring(end + 5)
            header.split("\n").forEach(function (l) {
                var idx = l.indexOf(":")
                if (idx > 0) {
                    var key = l.substring(0, idx).trim()
                    var val = l.substring(idx + 1).trim()
                    meta[key] = val
                }
            })
            return { meta: meta, body: body }
        }
    }
    return { meta: meta, body: raw }
}

function buildFrontMatter(meta, body) {
    var header = "---\n"
    header += "title: " + (meta.title || "") + "\n"
    header += "created: " + (meta.created || "") + "\n"
    header += "modified: " + (meta.modified || "") + "\n"
    header += "---\n"
    return header + (body || "")
}

function deriveTitle(meta, body) {
    if (meta && meta.title && meta.title.trim() !== "") return meta.title.trim()
    var lines = (body || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l === "") continue
        if (l.charAt(0) === "#") {
            return l.replace(/^#+\s*/, "").trim() || "Sem título"
        }
        return l.length > 60 ? l.substring(0, 60) + "…" : l
    }
    return "Sem título"
}

// Prévia pro card da lista: pula a primeira linha não-vazia (já usada
// como título) e junta as próximas, com a sintaxe de markdown mais
// comum removida.
function derivePreview(body) {
    var lines = (body || "").split("\n")
    var seenFirst = false
    var parts = []
    for (var i = 0; i < lines.length; i++) {
        var raw = lines[i].trim()
        if (raw === "") continue
        if (!seenFirst) { seenFirst = true; continue }
        var l = raw
            .replace(/^#+\s*/, "")
            .replace(/^-\s*\[[ xX]\]\s*/, "")
            .replace(/^[-*]\s+/, "")
            .replace(/[*_`]/g, "")
        parts.push(l)
        if (parts.join(" ").length > 100) break
    }
    var joined = parts.join(" ")
    return joined.length > 100 ? joined.substring(0, 100) + "…" : joined
}

function formatDate(iso) {
    if (!iso) return ""
    var d = new Date(iso)
    if (isNaN(d.getTime())) return ""
    function pad(n) { return n < 10 ? "0" + n : "" + n }
    return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() +
           " " + pad(d.getHours()) + ":" + pad(d.getMinutes())
}
