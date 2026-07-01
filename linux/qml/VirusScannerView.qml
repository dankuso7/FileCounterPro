import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import UI 1.0

Item {
    id: virusScannerView

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 30
        width: parent.width * 0.8

        Text {
            text: "SYSTEM VIRUS & THREAT SCANNER"
            color: SciFiTheme.textMain
            font.pixelSize: 32
            font.bold: true
            font.family: "Monospace"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Heuristic analysis of Linux critical paths (/tmp, ~/.config/autostart)"
            color: SciFiTheme.textDim
            font.pixelSize: 14
            font.family: "Monospace"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 600
            height: 300
            color: SciFiTheme.bgCard
            border.color: SciFiTheme.border
            border.width: 1
            radius: 12

            ColumnLayout {
                anchors.centerIn: parent
                visible: virusScannerBackend.threatCount === 0 && !virusScannerBackend.isScanning

                Text {
                    text: "SYSTEM SECURE"
                    color: SciFiTheme.neonGreen
                    font.pixelSize: 24
                    font.bold: true
                    font.family: "Monospace"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "No active threats detected in memory."
                    color: SciFiTheme.textDim
                    font.pixelSize: 12
                    font.family: "Monospace"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ListView {
                id: threatList
                anchors.fill: parent
                anchors.margins: 10
                visible: virusScannerBackend.threatCount > 0 || virusScannerBackend.isScanning
                model: virusScannerBackend.threats
                clip: true
                spacing: 10

                delegate: Rectangle {
                    width: threatList.width
                    height: 120
                    color: "#1a11111a"
                    border.color: SciFiTheme.neonMagenta
                    border.width: 1
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.fileName
                                color: SciFiTheme.neonMagenta
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Text {
                                text: modelData.filePath
                                color: SciFiTheme.textDim
                                font.pixelSize: 11
                            }
                            Text {
                                text: modelData.reason
                                color: SciFiTheme.neonMagenta
                                font.pixelSize: 11
                                font.italic: true
                                opacity: 0.8
                            }
                            Text {
                                text: modelData.aiExplanation
                                color: SciFiTheme.neonCyan
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            text: "🗑️ DELETE"
                            background: Rectangle {
                                color: "#33ff00ff"
                                border.color: SciFiTheme.neonMagenta
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: SciFiTheme.neonMagenta
                                font.bold: true
                            }
                            onClicked: {
                                virusScannerBackend.deleteThreat(modelData.filePath)
                            }
                        }
                    }
                }
            }
        }

        Button {
            text: virusScannerBackend.isScanning ? "SCANNING SYSTEM..." : "🚨 INITIATE FULL SYSTEM SCAN 🚨"
            Layout.alignment: Qt.AlignHCenter
            enabled: !virusScannerBackend.isScanning
            
            contentItem: Text {
                text: parent.text
                color: SciFiTheme.neonMagenta
                font.family: "Monospace"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                implicitWidth: 400
                implicitHeight: 45
                color: parent.down ? SciFiTheme.bgCard : "transparent"
                border.color: SciFiTheme.neonMagenta
                radius: 8
            }

            onClicked: {
                virusScannerBackend.scanCriticalPaths()
            }
        }
    }
}
