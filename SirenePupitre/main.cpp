#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "taperedboxgeometry.h"
#include "simpletestgeometry.h"
#include <QLoggingCategory>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QLoggingCategory::setFilterRules(QStringLiteral("qt.qml.binding.removal.info=true"));
    // Enregistrer les types custom pour QML
    qmlRegisterType<TaperedBoxGeometry>("GameGeometry", 1, 0, "TaperedBoxGeometry");
    qmlRegisterType<SimpleTestGeometry>("GameGeometry", 1, 0, "SimpleTestGeometry");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/QML/Main.qml")));

    return app.exec();
}
