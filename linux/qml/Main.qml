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

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: SciFiTheme.neonCyan
                    opacity: 0.1
                    radius: 8
                    border.color: SciFiTheme.neonCyan
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Dashboard"
                        color: SciFiTheme.neonCyan
                        font.family: "Monospace"
                        font.pixelSize: 14
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

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 30

                Text {
                    text: "LINUX DASHBOARD"
                    color: SciFiTheme.textMain
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "Monospace"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Scan any directory with zero memory overhead"
                    color: SciFiTheme.textDim
                    font.pixelSize: 14
                    font.family: "Monospace"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    width: 300
                    height: 150
                    color: "transparent"
                    border.color: SciFiTheme.neonPurple
                    border.width: 2
                    radius: 12
                    Layout.alignment: Qt.AlignHCenter

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 15

                        Text {
                            text: backendInfo.isScanning ? "SCANNING..." : (backendInfo.fileCount > 0 ? "TOTAL FILES" : "READY")
                            color: SciFiTheme.textDim
                            font.pixelSize: 12
                            font.family: "Monospace"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: backendInfo.fileCount.toString()
                            color: SciFiTheme.neonPurple
                            font.pixelSize: 48
                            font.bold: true
                            font.family: "Monospace"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                Button {
                    text: "Select Directory"
                    Layout.alignment: Qt.AlignHCenter
                    
                    contentItem: Text {
                        text: parent.text
                        color: SciFiTheme.neonPurple
                        font.family: "Monospace"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        implicitWidth: 200
                        implicitHeight: 45
                        color: parent.down ? SciFiTheme.bgCard : "transparent"
                        border.color: SciFiTheme.neonPurple
                        radius: 8
                    }

                    onClicked: folderDialog.open()
                }
            }
        }
    }
}
