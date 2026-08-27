import QtQuick

// Casque Bluetooth : nom et charge, lus sur le serveur node du Pi.
// PD n'a pas acces a D-Bus, et cette information est de la machine, pas de
// l'instrument — elle passe donc par /api/bluetooth et non par le WebSocket.
// L'hote vient de la page servie : en WASM le QML tourne dans le navigateur,
// donc `location.host` designe deja le Pi. Aucune adresse en dur.
Item {
    id: root

    property string apiHost: ""        // "" = meme hote que la page
    property int intervalMs: 20000     // la charge d'un casque bouge lentement

    readonly property bool connected: _connected
    readonly property string deviceName: _name
    readonly property int battery: _battery   // -1 = le casque ne la rapporte pas

    property bool _connected: false
    property string _name: ""
    property int _battery: -1

    function refresh() {
        var base = apiHost !== "" ? "http://" + apiHost : "";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { root._connected = false; return; }
            try {
                var d = JSON.parse(xhr.responseText);
                root._connected = d.connected === true;
                root._name = d.name || "";
                root._battery = (d.battery === null || d.battery === undefined) ? -1 : d.battery;
            } catch (e) {
                root._connected = false;
            }
        };
        xhr.open("GET", base + "/api/bluetooth");
        xhr.send();
    }

    // Reconnecter un casque allume apres le demarrage. Le serveur choisit parmi
    // les peripheriques deja appaires : rien a lui passer.
    signal connectFinished(bool ok)
    property bool connecting: false

    function connectHeadset() {
        if (connecting) return;
        connecting = true;
        var base = apiHost !== "" ? "http://" + apiHost : "";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.connecting = false;
            var ok = false;
            try { ok = JSON.parse(xhr.responseText).ok === true; } catch (e) {}
            root.connectFinished(ok);
            root.refresh();
        };
        xhr.open("POST", base + "/api/bluetooth/connect");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send("{}");
    }

    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
