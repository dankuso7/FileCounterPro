#ifndef HARDWAREANALYZERBACKEND_H
#define HARDWAREANALYZERBACKEND_H

#include <QObject>
#include <QString>

class HardwareAnalyzerBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString cpuName READ cpuName NOTIFY dataChanged)
    Q_PROPERTY(QString cpuCores READ cpuCores NOTIFY dataChanged)
    Q_PROPERTY(QString ramTotal READ ramTotal NOTIFY dataChanged)
    Q_PROPERTY(QString osName READ osName NOTIFY dataChanged)
    Q_PROPERTY(QString kernelVersion READ kernelVersion NOTIFY dataChanged)

public:
    explicit HardwareAnalyzerBackend(QObject *parent = nullptr);

    QString cpuName() const;
    QString cpuCores() const;
    QString ramTotal() const;
    QString osName() const;
    QString kernelVersion() const;

public slots:
    void loadHardwareData();

signals:
    void dataChanged();

private:
    QString m_cpuName;
    QString m_cpuCores;
    QString m_ramTotal;
    QString m_osName;
    QString m_kernelVersion;
};

#endif // HARDWAREANALYZERBACKEND_H
