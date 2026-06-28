#include "HardwareAnalyzerBackend.h"
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QtConcurrent>

HardwareAnalyzerBackend::HardwareAnalyzerBackend(QObject *parent)
    : QObject(parent)
{
}

QString HardwareAnalyzerBackend::cpuName() const { return m_cpuName; }
QString HardwareAnalyzerBackend::cpuCores() const { return m_cpuCores; }
QString HardwareAnalyzerBackend::ramTotal() const { return m_ramTotal; }
QString HardwareAnalyzerBackend::osName() const { return m_osName; }
QString HardwareAnalyzerBackend::kernelVersion() const { return m_kernelVersion; }

void HardwareAnalyzerBackend::loadHardwareData()
{
    QtConcurrent::run([this]() {
        QString cpuName = "Unknown CPU";
        int cores = 0;
        QFile cpuInfo("/proc/cpuinfo");
        if (cpuInfo.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&cpuInfo);
            while (!in.atEnd()) {
                QString line = in.readLine();
                if (line.startsWith("model name")) {
                    cpuName = line.split(":").last().trimmed();
                }
                if (line.startsWith("processor")) {
                    cores++;
                }
            }
            cpuInfo.close();
        }

        QString ramTotal = "Unknown RAM";
        QFile memInfo("/proc/meminfo");
        if (memInfo.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&memInfo);
            QString line = in.readLine();
            if (line.startsWith("MemTotal")) {
                QString kbString = line.split(":", Qt::SkipEmptyParts).last().replace("kB", "").trimmed();
                double gb = kbString.toDouble() / (1024.0 * 1024.0);
                ramTotal = QString::number(gb, 'f', 1) + " GB";
            }
            memInfo.close();
        }
        
        QString osName = "Linux";
        QFile osRelease("/etc/os-release");
        if (osRelease.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&osRelease);
            while (!in.atEnd()) {
                QString line = in.readLine();
                if (line.startsWith("PRETTY_NAME=")) {
                    osName = line.split("=").last().replace("\"", "");
                    break;
                }
            }
            osRelease.close();
        }

        QString kernelVersion = "Unknown Kernel";
        QFile version("/proc/version");
        if (version.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&version);
            QString line = in.readLine();
            QStringList parts = line.split(" ");
            if (parts.size() >= 3) {
                kernelVersion = parts[2];
            }
            version.close();
        }

        QMetaObject::invokeMethod(this, [this, cpuName, cores, ramTotal, osName, kernelVersion]() {
            m_cpuName = cpuName;
            m_cpuCores = QString::number(cores);
            m_ramTotal = ramTotal;
            m_osName = osName;
            m_kernelVersion = kernelVersion;
            emit dataChanged();
        });
    });
}
