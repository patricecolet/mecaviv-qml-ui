// Copyright (C) 2016 Klarälvdalens Datakonsult AB, a KDAB Group company, info@kdab.com, author Milian Wolff <milian.wolff@kdab.com>
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause

#include <QtGui/QGuiApplication>
//#include <QQuickView>

#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QSurfaceFormat>
#include <QDebug>

#ifdef Q_OS_WASM
#include <emscripten.h>
#endif

// Origine de la page qui héberge l'application, par exemple
// "http://192.168.1.21:8010" — vide hors navigateur.
//
// QML ne peut pas l'obtenir seul : sous WASM, un XMLHttpRequest vers une URL
// relative est résolu contre l'URL du fichier QML (qrc:/...) et finit en accès
// fichier local, refusé. C'est la seule raison d'être de ce détour par le C++ :
// sans lui, l'adresse du serveur resterait figée dans config.js au moment du
// build, et la page servie par le Raspberry chercherait Pure Data sur la
// machine du navigateur.
static QString pageOrigin()
{
#ifdef Q_OS_WASM
    char *origin = static_cast<char *>(
        emscripten_run_script_string("window.location.origin"));
    return origin ? QString::fromUtf8(origin) : QString();
#else
    return QString();
#endif
}

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QGuiApplication app(argc, argv);

    // ========== CONFIGURATION FPS GLOBAL ==========
    // Affichage 2D pur (plus de Qt Quick 3D). On garde le cap ~30 FPS,
    // utile sur Raspberry Pi en kiosque.
    QSurfaceFormat format;
    format.setSwapInterval(2);  // 30 FPS max (divise par 2)
    QSurfaceFormat::setDefaultFormat(format);
    // ===============================================
    
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("pageOrigin", pageOrigin());

    const QUrl url(u"qrc:/qml/qmlwebsocketserver/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
