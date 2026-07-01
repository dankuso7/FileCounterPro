import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import UI 1.0

ApplicationWindow {
    id: mainWindow
    width: 900
    height: 600
    visible: true
    title: "FileCounter Pro Linux"
    color: SciFiTheme.bgDeep

    FolderDialog {
        id: folderDialog
        title: "Select a folder to scan"
        onAccepted: {
            backendInfo.scanDirectory(folderDialog.currentFolder)
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: SciFiTheme.bgCard
            border.color: SciFiTheme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 20

                Text {
                    text: "FILE COUNTER PRO"
                    color: SciFiTheme.neonCyan
                    font.pixelSize: 16
                    font.bold: true
                    font.family: "Monospace"
                }

                // Navigation Buttons
                ColumnLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    // Dashboard Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: stackLayout.currentIndex === 0 ? "#3300ffff" : "transparent"
                        radius: 8
                        border.color: SciFiTheme.neonCyan
                        border.width: stackLayout.currentIndex === 0 ? 1 : 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: "📊 Dashboard"
                            color: SciFiTheme.neonCyan
                            font.family: "Monospace"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: stackLayout.currentIndex = 0
                        }
                    }

                    // Virus Scanner Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: stackLayout.currentIndex === 1 ? "#33ff00ff" : "transparent"
                        radius: 8
                        border.color: SciFiTheme.neonMagenta
                        border.width: stackLayout.currentIndex === 1 ? 1 : 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🛡️ Virus Scanner"
                            color: SciFiTheme.neonMagenta
                            font.family: "Monospace"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: stackLayout.currentIndex = 1
                        }
                    }

                    // Hardware Analyzer Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: stackLayout.currentIndex === 2 ? "#3339ff14" : "transparent"
                        radius: 8
                        border.color: SciFiTheme.neonGreen
                        border.width: stackLayout.currentIndex === 2 ? 1 : 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: "💻 Hardware Analyzer"
                            color: SciFiTheme.neonGreen
                            font.family: "Monospace"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: stackLayout.currentIndex = 2
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Main Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            StackLayout {
                id: stackLayout
                anchors.fill: parent
                currentIndex: 1
                
                onCurrentIndexChanged: {
                    contentFadeAnimation.restart()
                }

                DashboardView { }
                VirusScannerView { }
                HardwareAnalyzerView { }
            }

            PropertyAnimation {
                id: contentFadeAnimation
                target: stackLayout
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }
}
