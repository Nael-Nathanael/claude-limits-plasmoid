import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property int profile: Plasmoid.configuration.profile
    readonly property string provider: Plasmoid.configuration.provider
    // "claude-all": one pill per logged-in Claude Code profile the service has found.
    readonly property bool all: provider === "claude-all"
    readonly property string dir: `"\${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits"`
    // The files claude-limits-update (and Claude Code's statusline) keep fresh.
    readonly property string readCmd: all
        ? `cd ${dir} 2>/dev/null && for f in claude-*.json; do printf '%s\\t' "$f"; tr -d '\\n' < "$f"; echo; done`
        : `cat ${dir}/${provider === "claude" ? `claude-${profile}` : provider}.json`

    // Targets shown, e.g. ["claude-1", "claude-3"]; replaced only when the set changes, so pills don't flicker.
    property var targets: []
    property var quotas: ({})
    property double now: Date.now()

    Plasmoid.status: targets.length ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    // Each pill has its own tooltip.
    toolTipMainText: ""
    toolTipSubText: ""

    function read() {
        exec.connectSource(readCmd);
    }

    function show(found) {
        const names = Object.keys(found).filter(t => !found[t].hidden);
        if (all)
            names.sort((a, b) => a.split("-")[1] - b.split("-")[1]);
        quotas = found;
        if (JSON.stringify(names) !== JSON.stringify(targets))
            targets = names;
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            root.now = Date.now();
            if (source !== root.readCmd) {
                root.read();  // the forced refresh finished
                return;
            }
            const found = {};
            if (root.all) {
                for (const line of data["stdout"].split("\n")) {
                    const m = line.match(/^(claude-\d+)\.json\t(.+)$/);
                    try {
                        if (m)
                            found[m[1]] = JSON.parse(m[2]);
                    } catch (e) {}
                }
            } else {
                const t = root.provider === "claude" ? `claude-${root.profile}` : root.provider;
                try {
                    found[t] = JSON.parse(data["stdout"]);
                } catch (e) {
                    found[t] = { missing: true };
                }
            }
            root.show(found);
        }
    }

    // Reading small local files is cheap; the network work happens in the service.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.read()
    }

    preferredRepresentation: fullRepresentation
    fullRepresentation: RowLayout {
        spacing: Math.round(height * 0.3)
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.maximumWidth: implicitWidth

        Repeater {
            model: root.targets
            Pill {
                required property string modelData
                quota: root.quotas[modelData] || {}
                provider: modelData.startsWith("claude-") ? "claude" : modelData
                name: provider === "claude" ? `ccd ${modelData.split("-")[1]}` : modelData
                target: modelData
                now: root.now
                onRefresh: exec.connectSource(`"$HOME/.local/bin/claude-limits-update" --force ${modelData}`)
            }
        }
    }
}
