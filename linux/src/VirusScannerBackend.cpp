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
                        // Use QMetaObject::invokeMethod to safely update the UI thread
                        QMetaObject::invokeMethod(this, [this, fileInfo, sig]() {
                            addThreat(fileInfo.fileName(), fileInfo.absoluteFilePath(), "Matched known malicious signature: " + sig);
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

void VirusScannerBackend::addThreat(const QString &fileName, const QString &filePath, const QString &reason)
{
    QVariantMap threat;
    threat["fileName"] = fileName;
    threat["filePath"] = filePath;
    threat["reason"] = reason;
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
