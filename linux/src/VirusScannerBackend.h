#ifndef VIRUSSCANNERBACKEND_H
#define VIRUSSCANNERBACKEND_H

#include <QObject>
#include <QVariantList>

class VirusScannerBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)
    Q_PROPERTY(int threatCount READ threatCount NOTIFY threatCountChanged)
    Q_PROPERTY(QVariantList threats READ threats NOTIFY threatsChanged)

public:
    explicit VirusScannerBackend(QObject *parent = nullptr);

    bool isScanning() const;
    int threatCount() const;
    QVariantList threats() const;

public slots:
    void scanCriticalPaths();
    void deleteThreat(const QString &filePath);

signals:
    void isScanningChanged();
    void threatCountChanged();
    void threatsChanged();

private:
    bool m_isScanning;
    QVariantList m_threats;
    void addThreat(const QString &fileName, const QString &filePath, const QString &reason, const QString &aiExp);
};

#endif // VIRUSSCANNERBACKEND_H
