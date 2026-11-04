import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import "pace.js" as Pace

// One account: three lines (5h, 7d, safe pace), or two on Ultra.
PlasmaCore.ToolTipArea {
    id: pill

    required property var quota
    required property string provider
    required property string name
    required property string target
    required property double now
    signal refresh

    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"]
    // Set by the label. Light text means a dark panel behind it.
    property bool lightText: true

    // Pastels on a dark panel, deeper shades on a light one.
    function color(pct) {
        const c = lightText ? ["#ff6b6b", "#ffd166", "#8ce99a"] : ["#c92a2a", "#b35c00", "#2b8a3e"];
        return pct >= 80 ? c[0] : pct >= 50 ? c[1] : c[2];
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

    readonly property var fiveWin: quota.five_hour
    readonly property var weekWin: quota.seven_day
    readonly property var five: pctOf(fiveWin)
    readonly property var week: pctOf(weekWin)
    // The service refreshes every 5 minutes; much older means it is not running.
    readonly property bool old: !!quota.error || (!!quota.saved_at && now - quota.saved_at * 1000 > 600000)

    // Ultra has no 5-hour limit: only a weekly window comes back.
    readonly property bool weekOnly: !fiveWin && !!weekWin
    readonly property var pace: weekWin && weekWin.resets_at ? Pace.pace(weekWin.resets_at * 1000, now) : null

    readonly property bool loading: !fiveWin && !weekWin && !quota.error
    readonly property string weekReset: {
        const wr = resetAt(weekWin);
        return (wr ? `${hm(wr, ".")}@${months[wr.getMonth()]} ${wr.getDate()}` : "–") + (old ? '<font color="#888888">*</font>' : "");
    }

    location: Plasmoid.location
    mainText: quota.tier ? `${name}  ·  ${quota.tier}` : name
    subText: {
        if (quota.missing)
            return `No quota file yet: ~/.cache/claude-limits/${target}.json\nIs claude-limits.timer running?`;
        const day = d => d ? Qt.formatDateTime(d, "ddd HH:mm") : "–";
        const lines = [
            weekOnly ? "5h session   no limit" : `5h session   ${five ?? "–"}%   resets ${hm(resetAt(fiveWin), ":")}`,
            `7d week   ${week ?? "–"}%   resets ${day(resetAt(weekWin))}`,
        ];
        if (weekWin)
            lines.push(`Safe pace   ${pace ?? "–"}%   keep 7d under it to last the week with 10% spare`);
        // agy: one 5h and weekly limit per model group; the pill shows the most used.
        for (const g of quota.groups || [])
            lines.push(`${g.name}   5h ${pctOf(g["5h"]) ?? "–"}% · week ${pctOf(g.weekly) ?? "–"}%`);
        const note = [quota.error, quota.saved_at ? `updated ${day(new Date(quota.saved_at * 1000))}` : ""].filter(Boolean).join(" · ");
        if (note)
            lines.push(note);
        lines.push("Click to refresh");
        return lines.join("\n");
    }

    Layout.fillHeight: true
    Layout.minimumWidth: grid.implicitWidth
    Layout.preferredWidth: grid.implicitWidth
    Layout.maximumWidth: grid.implicitWidth

    // The applet box is shorter than the panel; the text may spill into its margin.
    readonly property int fontPx: Math.max(7, Math.min(10, Math.floor(height * 0.35)))
    readonly property bool tall: height > 26
    readonly property bool showPace: !loading && !!weekWin

    MouseArea {
        anchors.fill: parent
        onClicked: pill.refresh()
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        // Digits leave the descender space empty: centre the ink, not the boxes.
        anchors.verticalCenterOffset: 1
        columns: 2
        // Label boxes carry extra leading; overlap it so three lines fit.
        rowSpacing: -Math.round(pill.fontPx * (pill.tall ? 0.35 : 0.15))
        columnSpacing: pill.fontPx * 0.4

        component Cell: PlasmaComponents.Label {
            visible: text !== ""
            textFormat: Text.StyledText
            font.pixelSize: pill.fontPx
        }

        // Row 1: 5h, or 7d on Ultra.
        Cell {
            Layout.alignment: Qt.AlignRight
            text: pill.loading ? `${pill.name} …` : pill.weekOnly ? pill.num(pill.week) : pill.num(pill.five)

            // The text colour comes from the Plasma style, or from Panel Colorizer.
            readonly property bool light: 0.299 * color.r + 0.587 * color.g + 0.114 * color.b > 0.5
            onLightChanged: pill.lightText = light
            Component.onCompleted: pill.lightText = light
        }
        // The 5h reset is shorter than the 7d one: the logo fills the gap.
        RowLayout {
            Layout.fillWidth: true
            spacing: pill.fontPx * 0.4
            Cell {
                text: pill.loading ? "" : pill.weekOnly ? pill.weekReset : pill.hm(pill.resetAt(pill.fiveWin), ".")
            }
            Item {
                Layout.fillWidth: true
            }
            Image {
                source: Qt.resolvedUrl(`../images/${{ claude: "claude.svg", codex: "codex.svg", agy: "agy.png" }[pill.provider]}`)
                sourceSize: Qt.size(pill.fontPx, pill.fontPx)
                Layout.preferredWidth: pill.fontPx
                Layout.preferredHeight: pill.fontPx
            }
        }
        // Row 2: 7d.
        Cell {
            Layout.alignment: Qt.AlignRight
            text: pill.loading || pill.weekOnly ? "" : pill.num(pill.week)
        }
        Cell {
            text: pill.loading || pill.weekOnly ? "" : pill.weekReset
        }
        // Last row: safe pace in grey, and a bar of the week: grey = time gone, colour = 7d used.
        Cell {
            Layout.alignment: Qt.AlignRight
            visible: pill.showPace
            text: `<font color="#888888">${pill.pace ?? "–"}%</font>`
        }
        Item {
            visible: pill.showPace
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(2, Math.round(pill.fontPx * 0.3))
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#888888"
                opacity: 0.25
            }
            Rectangle {
                width: parent.width * (pill.pace ?? 0) / 100
                height: parent.height
                radius: height / 2
                color: "#888888"
            }
            Rectangle {
                width: parent.width * Math.min(100, pill.week ?? 0) / 100
                height: parent.height
                radius: height / 2
                color: pill.color(pill.week ?? 0)
            }
        }
    }
}
