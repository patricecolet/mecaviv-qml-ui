#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QLoggingCategory>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QLoggingCategory::setFilterRules(QStringLiteral("qt.qml.binding.removal.info=true"));

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
