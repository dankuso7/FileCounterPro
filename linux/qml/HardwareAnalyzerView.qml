import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import UI 1.0

Item {
    id: hardwareAnalyzerView

    Component.onCompleted: {
        hardwareBackend.loadHardwareData()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 30
        width: parent.width * 0.9

        Text {
            text: "HARDWARE DIAGNOSTICS"
            color: SciFiTheme.textMain
            font.pixelSize: 32
            font.bold: true
            font.family: "Monospace"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Live /proc/ polling for critical system infrastructure."
            color: SciFiTheme.textDim
            font.pixelSize: 14
            font.family: "Monospace"
            Layout.alignment: Qt.AlignHCenter
        }

        GridLayout {
            columns: 2
            rowSpacing: 20
            columnSpacing: 20
            Layout.alignment: Qt.AlignHCenter

            // CPU Info
            Rectangle {
                width: 350
                height: 150
                color: SciFiTheme.bgCard
                border.color: SciFiTheme.neonCyan
                border.width: 1
                radius: 12

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "CPU ARCHITECTURE"
                        color: SciFiTheme.neonCyan
                        font.bold: true
                        font.pixelSize: 12
                    }
                    Text {
                        text: hardwareBackend.cpuName
                        color: SciFiTheme.textMain
                        font.pixelSize: 18
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 300
                    }
                    Text {
                        text: hardwareBackend.cpuCores + " Cores"
                        color: SciFiTheme.textDim
                        font.pixelSize: 12
                    }
                }
            }

            // RAM Info
            Rectangle {
                width: 350
                height: 150
                color: SciFiTheme.bgCard
                border.color: SciFiTheme.neonPurple
                border.width: 1
                radius: 12

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "PHYSICAL MEMORY"
                        color: SciFiTheme.neonPurple
                        font.bold: true
                        font.pixelSize: 12
                    }
                    Text {
                        text: hardwareBackend.ramTotal
                        color: SciFiTheme.textMain
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: "Total Installed Capacity"
                        color: SciFiTheme.textDim
                        font.pixelSize: 12
                    }
                }
            }

            // GPU Info
            Rectangle {
                Layout.columnSpan: 2
                width: 720
                height: 150
                color: SciFiTheme.bgCard
                border.color: SciFiTheme.neonGreen
                border.width: 1
                radius: 12
                Layout.alignment: Qt.AlignHCenter

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "SYSTEM OS / KERNEL"
                        color: SciFiTheme.neonGreen
                        font.bold: true
                        font.pixelSize: 12
                    }
                    Text {
                        text: hardwareBackend.osName
                        color: SciFiTheme.textMain
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: hardwareBackend.kernelVersion
                        color: SciFiTheme.textDim
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
