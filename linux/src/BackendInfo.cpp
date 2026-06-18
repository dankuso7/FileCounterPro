#include "BackendInfo.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QThread>
#include <QtConcurrent>

BackendInfo::BackendInfo(QObject *parent) : QObject(parent) {}

int BackendInfo::fileCount() const {
    return m_fileCount;
}

bool BackendInfo::isScanning() const {
    return m_isScanning;
}

void BackendInfo::scanDirectory(const QString &path) {
    if (m_isScanning) return;

    m_isScanning = true;
    emit isScanningChanged();
    m_fileCount = 0;
    emit fileCountChanged();

    // Remove file:// prefix if present
    QString localPath = path;
    if (localPath.startsWith("file://")) {
        localPath = localPath.mid(7);
    }

    QtConcurrent::run([this, localPath]() {
        int count = 0;
        QDirIterator it(localPath, QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden, QDirIterator::Subdirectories);
        
        while (it.hasNext()) {
            it.next();
            count++;
            
            // Update UI periodically to prevent lag
            if (count % 100 == 0) {
                QMetaObject::invokeMethod(this, [this, count]() {
                    m_fileCount = count;
                    emit fileCountChanged();
                }, Qt::QueuedConnection);
            }
        }

        QMetaObject::invokeMethod(this, [this, count]() {
            m_fileCount = count;
            m_isScanning = false;
            emit fileCountChanged();
            emit isScanningChanged();
            emit scanCompleted(count);
        }, Qt::QueuedConnection);
    });
}
