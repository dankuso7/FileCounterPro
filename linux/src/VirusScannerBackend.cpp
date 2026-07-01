#include "VirusScannerBackend.h"
#include <QDir>
#include <QFileInfo>
#include <QVariantMap>
#include <QTimer>
#include <QtConcurrent>
#include <QFile>

VirusScannerBackend::VirusScannerBackend(QObject *parent)
    : QObject(parent), m_isScanning(false)
{
}

bool VirusScannerBackend::isScanning() const { return m_isScanning; }
int VirusScannerBackend::threatCount() const { return m_threats.size(); }
QVariantList VirusScannerBackend::threats() const { return m_threats; }

void VirusScannerBackend::scanCriticalPaths()
{
    if (m_isScanning) return;
    
    m_isScanning = true;
    emit isScanningChanged();
    
    m_threats.clear();
    emit threatsChanged();
    emit threatCountChanged();

    QtConcurrent::run([this]() {
        QStringList paths = { "/tmp", QDir::homePath() + "/.config/autostart" };
        QStringList badSignatures = { "minerd", "xmrig", "nc", "trojan" };

        for (const QString &path : paths) {
            QDir dir(path);
            if (!dir.exists()) continue;

            QFileInfoList list = dir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot);
            for (const QFileInfo &fileInfo : list) {
                QString name = fileInfo.fileName().toLower();
                for (const QString &sig : badSignatures) {
                    if (name.contains(sig)) {
                        QString reason = "Matched known malicious signature: " + sig;
                        QString aiExp = "⚠️ **DELETION IMPACT ANALYSIS:**\n";
                        QString lowerPath = fileInfo.absoluteFilePath().toLower();
                        
                        if (lowerPath.contains("/usr/") || lowerPath.contains("/bin/") || lowerPath.contains("/sbin/") || lowerPath.contains("/etc/") || lowerPath.contains("/lib")) {
                            aiExp += "CRITICAL WARNING: This is a core Linux system path. Deleting this may break your operating system, package manager, or prevent booting. Do not delete unless you are a Linux expert.";
                        } else if (lowerPath.contains("/steamapps/common/") || lowerPath.contains("/games/") || lowerPath.contains(".local/share/lutris/runners/")) {
                            aiExp += "This appears to be part of a Game installation (e.g. Steam, Lutris). Deleting it will likely corrupt the game or translation layer (like Proton/Wine). False positives are common with game anti-cheat systems.";
                        } else if (lowerPath.contains(".config/autostart/")) {
                            aiExp += "This file is configured to run automatically when you log in. Deleting it will stop the program from auto-starting, which is safe if you don't recognize the program.";
                        } else if (lowerPath.contains("/tmp/")) {
                            aiExp += "This file is in the temporary directory. It is generally safe to delete, as the system clears this folder on reboot anyway.";
                        } else {
                            aiExp += "Deleting this file will permanently remove it. If it belongs to a specific application, that application may stop working properly.";
                        }
                        
                        QMetaObject::invokeMethod(this, [this, fileInfo, reason, aiExp]() {
                            addThreat(fileInfo.fileName(), fileInfo.absoluteFilePath(), reason, aiExp);
                        });
                        break; // Stop checking this file if one matches
                    }
                }
            }
        }

        QMetaObject::invokeMethod(this, [this]() {
            m_isScanning = false;
            emit isScanningChanged();
        });
    });
}

void VirusScannerBackend::addThreat(const QString &fileName, const QString &filePath, const QString &reason, const QString &aiExp)
{
    QVariantMap threat;
    threat["fileName"] = fileName;
    threat["filePath"] = filePath;
    threat["reason"] = reason;
    threat["aiExplanation"] = aiExp;
    m_threats.append(threat);
    emit threatsChanged();
    emit threatCountChanged();
}

void VirusScannerBackend::deleteThreat(const QString &filePath)
{
    if (QFile::remove(filePath)) {
        for (int i = 0; i < m_threats.size(); ++i) {
            if (m_threats[i].toMap()["filePath"].toString() == filePath) {
                m_threats.removeAt(i);
                emit threatsChanged();
                emit threatCountChanged();
                break;
            }
        }
    }
}
