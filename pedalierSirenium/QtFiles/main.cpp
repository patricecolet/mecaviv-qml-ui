// Copyright (C) 2016 Klarälvdalens Datakonsult AB, a KDAB Group company, info@kdab.com, author Milian Wolff <milian.wolff@kdab.com>
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause

#include <QtGui/QGuiApplication>
//#include <QQuickView>

#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QSurfaceFormat>
#include <QDebug>

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
    
/*
    QQuickView view;
    view.setSource(QUrl(QStringLiteral("qrc:/qml/qmlwebsocketserver/main.qml")));
    view.show();
*/
 //   QSurfaceFormat::setDefaultFormat(QQuick3D::idealSurfaceFormat());

    QQmlApplicationEngine engine;

    const QUrl url(u"qrc:/qml/qmlwebsocketserver/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
