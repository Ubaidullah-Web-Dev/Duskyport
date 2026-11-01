pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cross-surface presentation preferences from Dusky store.
Singleton {
    id: root

    property bool showJapaneseGloss: true

    function containsJapanese(value) {
        return /[\u3040-\u30ff\u3400-\u9fff]/.test(String(value || ""));
    }

    function text(value, fallback) {
        const source = String(value || "");
        return root.showJapaneseGloss || !root.containsJapanese(source)
            ? source : String(fallback || "");
    }

    function shippedText(value, shippedValue, fallback) {
        const source = String(value || "");
        return !root.showJapaneseGloss && source === String(shippedValue || "")
            ? String(fallback || "") : source;
    }

    function brandMark(value) {
        const source = String(value || "") || "港";
        return !root.showJapaneseGloss && source === "港" ? "DP" : source;
    }

    function load() {
        var data = {};
        try { data = JSON.parse(store.text()) || {}; } catch (e) {}
        root.showJapaneseGloss = data.showJapaneseGloss !== false;
    }

    FileView {
        id: store
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/duskyport/config.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.load()
        onFileChanged: reload()
        onLoadFailed: root.showJapaneseGloss = true
    }
}
