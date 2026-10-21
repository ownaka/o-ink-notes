import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

// Executa um comando de shell e devolve stdout/exitCode via callback.
// É o único jeito de rodar processos (escrever/apagar arquivo, chamar
// qdbus6) a partir de QML puro, sem plugin C++.
Item {
    id: root

    property var _pending: ({})

    Plasma5Support.DataSource {
        id: source
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            // sourceName é o próprio comando: a engine "executable" usa o
            // comando como identificador da fonte.
            var cbs = root._pending[sourceName]
            if (cbs && cbs.length > 0) {
                var cb = cbs.shift()
                if (cbs.length === 0) delete root._pending[sourceName]
                cb(data["stdout"] ? data["stdout"].toString() : "",
                   data["exit code"] !== undefined ? data["exit code"] : -1,
                   data["stderr"] ? data["stderr"].toString() : "")
            }
        }
    }

    // Escapa uma string para uso seguro entre aspas simples no shell.
    function quote(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'"
    }

    function run(cmd, callback) {
        // Enfileira callbacks por comando (suporta comandos idênticos
        // concorrentes, raro nesse app, mas evita perder uma resposta).
        if (!root._pending[cmd]) root._pending[cmd] = []
        root._pending[cmd].push(callback)
        source.connectSource(cmd)
    }
}
