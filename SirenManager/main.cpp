#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QStandardPaths>
#include <QtQml>
#include "src/UdpController.h"
#include "src/SshController.h"
#include "src/PlaylistManager.h"
#include "src/Models/PlaylistModel.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Configuration de l'application
    app.setApplicationName("SirenManager");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Mecaviv");
    app.setOrganizationDomain("mecaviv.com");

    // Enregistrer les types QML
    qmlRegisterType<UdpController>("SirenManager", 1, 0, "UdpController");
    qmlRegisterType<PlaylistManager>("SirenManager", 1, 0, "PlaylistManager");
    qmlRegisterType<PlaylistModel>("SirenManager", 1, 0, "PlaylistModel");

    // Single shared UDP controller across all views — only one process can
    // bind the receive port (8000), and switching destination per call works
    // because sendCommandToMachine updates the address before each send.
    auto *udpManager = new UdpController();
    udpManager->connectToHost(QStringLiteral("192.168.1.101"), 8001);
    qmlRegisterSingletonInstance("SirenManager", 1, 0, "UdpManager", udpManager);

    // SSH controller — proxies through the Node.js backend on localhost:8005.
    // Backend must be running for SystemMaintenance / PlaylistComposer views.
    auto *sshManager = new SshController();
    qmlRegisterSingletonInstance("SirenManager", 1, 0, "SshManager", sshManager);

    // Créer le moteur QML
    QQmlApplicationEngine engine;

    // Ajouter le chemin des ressources
    const QUrl url(QStringLiteral("qrc:/SirenManager/QML/Main.qml"));

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

