import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_profile: profile.value

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: profile
            Kirigami.FormData.label: "Profile:"
            from: 1
            to: 99
        }
        QQC2.Label {
            text: "1 is plain Claude Code (~/.claude).\nN is ccd profile N (~/.claude-profile-N)."
            opacity: 0.7
        }
    }
}
