#ifndef BACKENDINFO_H
#define BACKENDINFO_H

#include <QObject>
#include <QString>

class BackendInfo : public QObject {
    Q_OBJECT
    Q_PROPERTY(int fileCount READ fileCount NOTIFY fileCountChanged)
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)

public:
    explicit BackendInfo(QObject *parent = nullptr);

    int fileCount() const;
    bool isScanning() const;

public slots:
    void scanDirectory(const QString &path);

signals:
    void fileCountChanged();
    void isScanningChanged();
    void scanCompleted(int totalFiles);

private:
    int m_fileCount = 0;
    bool m_isScanning = false;
};

#endif // BACKENDINFO_H
