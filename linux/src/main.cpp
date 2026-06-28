#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "BackendInfo.h"
#include "VirusScannerBackend.h"
#include "HardwareAnalyzerBackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    // Register BackendInfo with QML
    BackendInfo backendInfo;
    VirusScannerBackend virusScannerBackend;
    HardwareAnalyzerBackend hardwareBackend;

    engine.rootContext()->setContextProperty("backendInfo", &backendInfo);
    engine.rootContext()->setContextProperty("virusScannerBackend", &virusScannerBackend);
    engine.rootContext()->setContextProperty("hardwareBackend", &hardwareBackend);

    const QUrl url(u"qrc:/qml/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
