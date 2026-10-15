import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property int profile: Plasmoid.configuration.profile
    readonly property string provider: Plasmoid.configuration.provider
    readonly property bool claude: provider === "claude"
    readonly property string name: claude ? `ccd ${profile}` : provider
    // The file claude-limits-update (and Claude Code's statusline) keeps fresh.
    readonly property string target: claude ? `claude-${profile}` : provider
    readonly property string readCmd: `cat "\${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits/${target}.json"`
    readonly property string forceCmd: `"$HOME/.local/bin/claude-limits-update" --force ${target}`
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"]

    property var state: ({})
    property double now: Date.now()

    function color(pct) {
        return pct >= 80 ? "#ff6b6b" : pct >= 50 ? "#ffd166" : "#8ce99a";
    }

    // Resets land at hh:59:59.9; round to the nearest minute.
    function resetAt(win) {
        return win && win.resets_at ? new Date(win.resets_at * 1000 + 30000) : null;
    }

    // A window whose reset time has passed is back to 0%.
    function pctOf(win) {
        if (!win)
            return null;
        if (win.resets_at && win.resets_at * 1000 <= now)
            return 0;
        return Math.round(win.used_percentage);
    }

    function hm(d, sep) {
        return d ? Qt.formatTime(d, "HH" + sep + "mm") : "–";
    }

    function num(p) {
        return p === null ? "–" : `<font color="${color(p)}">${p}%</font>`;
    }

    readonly property var fiveWin: state.five_hour
    readonly property var weekWin: state.seven_day
    readonly property var five: pctOf(fiveWin)
    readonly property var week: pctOf(weekWin)
    // The service refreshes every 5 minutes; much older means it is not running.
    readonly property bool old: !!state.error || (!!state.saved_at && now - state.saved_at * 1000 > 600000)

    // Pill cells, two per row (percent, reset): 5h over 7d.
    readonly property var cells: {
        if (!fiveWin && !weekWin && !state.error)
            return [`${name} …`, ""];
        const stale = old ? '<font color="#888888">*</font>' : "";
        const wr = resetAt(weekWin);
        const weekReset = wr ? `${hm(wr, ".")}@${months[wr.getMonth()]} ${wr.getDate()}` : "–";
        return [num(five), hm(resetAt(fiveWin), "."), num(week), weekReset + stale];
    }

    Plasmoid.status: state.hidden ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.ActiveStatus

    toolTipMainText: state.tier ? `${name}  ·  ${state.tier}` : name
    toolTipSubText: {
        if (state.missing)
            return `No quota file yet: ~/.cache/claude-limits/${target}.json\nIs claude-limits.timer running?`;
        const day = d => d ? Qt.formatDateTime(d, "ddd HH:mm") : "–";
        const lines = [
            `5h session   ${five ?? "–"}%   resets ${hm(resetAt(fiveWin), ":")}`,
            `7d week   ${week ?? "–"}%   resets ${day(resetAt(weekWin))}`,
        ];
        // agy: one 5h and weekly limit per model group; the pill shows the most used.
        for (const g of state.groups || [])
            lines.push(`${g.name}   5h ${pctOf(g["5h"]) ?? "–"}% · week ${pctOf(g.weekly) ?? "–"}%`);
        const note = [state.error, state.saved_at ? `updated ${day(new Date(state.saved_at * 1000))}` : ""].filter(Boolean).join(" · ");
        if (note)
            lines.push(note);
        lines.push("Click to refresh");
        return lines.join("\n");
    }

    function read() {
        exec.connectSource(readCmd);
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
            try {
                root.state = JSON.parse(data["stdout"]);
            } catch (e) {
                root.state = { missing: true };
            }
        }
    }

    // Reading a small local file is cheap; the network work happens in the service.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.read()
    }

    preferredRepresentation: fullRepresentation
    fullRepresentation: MouseArea {
        id: pill
        Layout.minimumWidth: grid.implicitWidth
        Layout.preferredWidth: grid.implicitWidth
        Layout.maximumWidth: grid.implicitWidth
        onClicked: exec.connectSource(root.forceCmd)

        // Two lines share the panel height.
        // Capped so tall pills keep room above and below the text.
        readonly property int fontPx: Math.max(8, Math.min(10, Math.floor(height * 0.4)))
        readonly property bool tall: height > 26

        GridLayout {
            id: grid
            anchors.centerIn: parent
            columns: 2
            rowSpacing: pill.tall ? -Math.round(pill.fontPx * 0.35) : 0
            columnSpacing: pill.fontPx * 0.4

            component Cell: PlasmaComponents.Label {
                visible: text !== ""
                textFormat: Text.StyledText
                font.pixelSize: pill.fontPx
            }

            Cell {
                Layout.alignment: Qt.AlignRight
                text: root.cells[0]
            }
            // The 5h reset is shorter than the 7d one: the logo fills the gap.
            RowLayout {
                Layout.fillWidth: true
                spacing: pill.fontPx * 0.4
                Cell {
                    text: root.cells[1]
                }
                Item {
                    Layout.fillWidth: true
                }
                Image {
                    source: Qt.resolvedUrl(`../images/${{ claude: "claude.svg", codex: "codex.svg", agy: "agy.png" }[root.provider]}`)
                    sourceSize: Qt.size(pill.fontPx, pill.fontPx)
                    Layout.preferredWidth: pill.fontPx
                    Layout.preferredHeight: pill.fontPx
                }
            }
            Cell {
                Layout.alignment: Qt.AlignRight
                text: root.cells[2] ?? ""
            }
            Cell {
                text: root.cells[3] ?? ""
            }
        }
    }
}
