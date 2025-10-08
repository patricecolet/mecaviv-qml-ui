#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QStandardPaths>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Configuration de l'application
    app.setApplicationName("SirenConsole");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Mecaviv");
    app.setOrganizationDomain("mecaviv.com");

    // Créer le moteur QML
    QQmlApplicationEngine engine;

    // Ajouter le chemin des ressources
    const QUrl url(QStringLiteral("qrc:/SirenConsole/QML/Main.qml"));

    // Connexion pour gérer les erreurs de chargement
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    // Charger le fichier QML principal
    engine.load(url);

    return app.exec();
}
