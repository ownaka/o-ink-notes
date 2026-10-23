import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

// Executa um comando de shell e devolve stdout/exitCode via callback.
// É o único jeito de rodar processos (escrever/apagar arquivo, chamar
// qdbus6) a partir de QML puro, sem plugin C++.
Item {
    id: root

    property var _pending: ({})
    property int _seq: 0

    Plasma5Support.DataSource {
        id: source
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            // sourceName é o comando (mais um comentário "# <n>" no final
            // pra ficar único — ver run()). A engine "executable" usa o
            // sourceName como identificador E CACHE: reconectar com o
            // mesmo texto devolve a resposta antiga em vez de rodar de
            // novo, então cada chamada precisa de um sourceName inédito.
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
        // "# <contador>" no final é só um comentário de shell (não muda o
        // que o comando faz) — existe só pra tornar o sourceName único a
        // cada chamada, mesmo quando o MESMO comando (ex. ler o mesmo
        // arquivo duas vezes seguidas) é rodado de novo. Sem isso, a
        // engine "executable" do Plasma devolve a resposta em cache da
        // vez anterior em vez de executar de novo (confirmado na prática
        // — é a causa de notas aparentando conteúdo desatualizado).
        root._seq++
        var sourceName = cmd + " # " + root._seq
        if (!root._pending[sourceName]) root._pending[sourceName] = []
        root._pending[sourceName].push(callback)
        source.connectSource(sourceName)
    }
}
