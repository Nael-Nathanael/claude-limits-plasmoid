import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property int profile: Plasmoid.configuration.profile
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../tools/usage.py").toString().replace("file://", ""))
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"]

    property var info: ({})
    property double now: Date.now()

    function color(pct) {
        return pct >= 80 ? "#ff6b6b" : pct >= 50 ? "#ffd166" : "#8ce99a";
    }

    // Resets land at hh:59:59.9; round to the nearest minute.
    function resetAt(win) {
        return win && win.resets_at ? new Date(new Date(win.resets_at).getTime() + 30000) : null;
    }

    // A window whose reset time has passed is back to 0%.
    function pctOf(win) {
        if (!win)
            return null;
        if (win.resets_at && new Date(win.resets_at).getTime() <= now)
            return 0;
        return Math.round(win.utilization);
    }

    function hm(d, sep) {
        return d ? Qt.formatTime(d, "HH" + sep + "mm") : "–";
    }

    function num(p) {
        return p === null ? "–" : `<font color="${color(p)}">${p}%</font>`;
    }

    readonly property var fiveWin: info.usage ? info.usage.five_hour : null
    readonly property var weekWin: info.usage ? info.usage.seven_day : null
    readonly property var five: pctOf(fiveWin)
    readonly property var week: pctOf(weekWin)

    readonly property string text: {
        const stale = info.error ? '<font color="#888888">*</font>' : "";
        const wr = resetAt(weekWin);
        const weekReset = wr ? `${hm(wr, ".")}@${months[wr.getMonth()]} ${wr.getDate()}` : "–";
        // Week too used up for the days left: the 5h numbers don't matter, only when it comes back.
        // Cutoff drops 5 points per day left on 20x, 10 on 5x.
        const daysLeft = wr ? (wr.getTime() - now) / 86400000 : 0;
        const cutoff = 100 - ((info.tier || "").includes("20x") ? 5 : 10) * daysLeft;
        if (week !== null && week >= cutoff)
            return `<font color="${color(week)}">${weekReset}</font>${stale}`;
        return `${num(five)} ${hm(resetAt(fiveWin), ".")} — ${num(week)} ${weekReset}${stale}`;
    }

    Plasmoid.status: info.hidden ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.ActiveStatus

    readonly property string profileName: profile === 1 ? "Claude Code" : `ccd ${profile}`

    toolTipMainText: `${profileName}  ·  ${info.tier || "?"}`
    toolTipSubText: {
        const day = d => d ? Qt.formatDateTime(d, "ddd HH:mm") : "–";
        const lines = [
            `5h session   ${five ?? "–"}%   resets ${hm(resetAt(fiveWin), ":")}`,
            `7d week   ${week ?? "–"}%   resets ${day(resetAt(weekWin))}`,
        ];
        const note = [info.error, info.at ? `updated ${day(new Date(info.at * 1000))}` : ""].filter(Boolean).join(" · ");
        if (note)
            lines.push(note);
        lines.push("Click to refresh");
        return lines.join("\n");
    }

    function refresh(force) {
        exec.connectSource(`python3 '${script}' ${profile}${force ? " force" : ""}`);
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            try {
                root.info = JSON.parse(data["stdout"]);
            } catch (e) {
                console.error("claude limits:", data["stderr"] || e);
            }
            root.now = Date.now();
        }
    }

    // The script only hits the API when its cache is stale or the token was renewed.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(false)
    }

    preferredRepresentation: fullRepresentation
    fullRepresentation: MouseArea {
        Layout.minimumWidth: label.implicitWidth
        Layout.preferredWidth: label.implicitWidth
        Layout.maximumWidth: label.implicitWidth
        onClicked: root.refresh(true)

        PlasmaComponents.Label {
            id: label
            anchors.centerIn: parent
            textFormat: Text.StyledText
            text: root.info.usage || root.info.error ? root.text : `${root.profileName} …`
        }
    }
}
