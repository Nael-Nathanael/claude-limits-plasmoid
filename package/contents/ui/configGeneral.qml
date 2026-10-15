import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_profile: profile.value
    property string cfg_provider

    readonly property var providers: ["claude", "codex", "agy"]

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: "Account:"
            model: ["Claude Code", "Codex", "Antigravity (agy)"]
            currentIndex: Math.max(0, providers.indexOf(cfg_provider))
            onActivated: index => cfg_provider = providers[index]
        }
        QQC2.SpinBox {
            id: profile
            Kirigami.FormData.label: "Profile:"
            enabled: cfg_provider === "claude"
            from: 1
            to: 99
        }
        QQC2.Label {
            text: "1 is plain Claude Code (~/.claude).\nN is ccd profile N (~/.claude-profile-N)."
            opacity: 0.7
        }
    }
}
