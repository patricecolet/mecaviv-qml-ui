#include "SshController.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QUrl>

SshController::SshController(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
    , m_backendUrl(QStringLiteral("http://localhost:8005"))
{
}

void SshController::setBackendUrl(const QString &url)
{
    if (m_backendUrl != url) {
        m_backendUrl = url;
        emit backendUrlChanged(m_backendUrl);
    }
}

QString SshController::machineTypeToString(int machineType)
{
    // Must match backend/config.json keys (linuxMaitre, raspberryClic, s1..s7, etc.).
    switch (static_cast<MachineType>(machineType)) {
        case MachineType::LinuxMaitre:   return QStringLiteral("linuxMaitre");
        case MachineType::RaspberryClic: return QStringLiteral("raspberryClic");
        case MachineType::S1: return QStringLiteral("s1");
        case MachineType::S2: return QStringLiteral("s2");
        case MachineType::S3: return QStringLiteral("s3");
        case MachineType::S4: return QStringLiteral("s4");
        case MachineType::S5: return QStringLiteral("s5");
        case MachineType::S6: return QStringLiteral("s6");
        case MachineType::S7: return QStringLiteral("s7");
        case MachineType::VoitureA: return QStringLiteral("voitureA");
        case MachineType::VoitureB: return QStringLiteral("voitureB");
        case MachineType::Pavillon1: return QStringLiteral("pavillon1");
        case MachineType::Pavillon2: return QStringLiteral("pavillon2");
        default: return QStringLiteral("linuxMaitre");
    }
}

void SshController::postJson(const QString &path, const QByteArray &body,
                             std::function<void(QNetworkReply*)> handler)
{
    QNetworkRequest req(QUrl(m_backendUrl + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QNetworkReply *reply = m_network->post(req, body);
    connect(reply, &QNetworkReply::finished, this, [reply, handler]() {
        handler(reply);
        reply->deleteLater();
    });
}

// Parse the backend's JSON body even on HTTP error — Express's
// res.status(500).json({ success:false, error:"..." }) carries the real SSH
// error message there. Falling back to QNetworkReply::errorString() loses it.
static QJsonObject readReplyBody(QNetworkReply *reply)
{
    return QJsonDocument::fromJson(reply->readAll()).object();
}

void SshController::executeCommand(int machineType, const QString &command, const QString &requestId)
{
    QJsonObject body;
    body[QStringLiteral("machineType")] = machineTypeToString(machineType);
    body[QStringLiteral("command")] = command;
    QByteArray json = QJsonDocument(body).toJson(QJsonDocument::Compact);

    postJson(QStringLiteral("/api/ssh/execute"), json, [this, requestId](QNetworkReply *reply) {
        QJsonObject obj = readReplyBody(reply);
        bool success = obj.value(QStringLiteral("success")).toBool();
        QString output = obj.value(QStringLiteral("output")).toString();
        QString errorStr = obj.value(QStringLiteral("error")).toString();
        if (errorStr.isEmpty() && reply->error() != QNetworkReply::NoError) {
            errorStr = reply->errorString();
        }
        emit commandFinished(requestId, success, output, errorStr);
    });
}

void SshController::downloadFile(int machineType, const QString &remotePath, const QString &requestId)
{
    QJsonObject body;
    body[QStringLiteral("machineType")] = machineTypeToString(machineType);
    body[QStringLiteral("remotePath")] = remotePath;
    QByteArray json = QJsonDocument(body).toJson(QJsonDocument::Compact);

    postJson(QStringLiteral("/api/ssh/download"), json, [this, requestId](QNetworkReply *reply) {
        QJsonObject obj = readReplyBody(reply);
        bool success = obj.value(QStringLiteral("success")).toBool();
        QString content = obj.value(QStringLiteral("content")).toString();
        QString errorStr = obj.value(QStringLiteral("error")).toString();
        if (errorStr.isEmpty() && reply->error() != QNetworkReply::NoError) {
            errorStr = reply->errorString();
        }
        emit downloadFinished(requestId, success, content, errorStr);
    });
}

void SshController::uploadFile(int machineType, const QString &remotePath, const QString &content, const QString &requestId)
{
    QJsonObject body;
    body[QStringLiteral("machineType")] = machineTypeToString(machineType);
    body[QStringLiteral("remotePath")] = remotePath;
    body[QStringLiteral("content")] = content;
    QByteArray json = QJsonDocument(body).toJson(QJsonDocument::Compact);

    postJson(QStringLiteral("/api/ssh/upload"), json, [this, requestId](QNetworkReply *reply) {
        QJsonObject obj = readReplyBody(reply);
        bool success = obj.value(QStringLiteral("success")).toBool();
        QString errorStr = obj.value(QStringLiteral("error")).toString();
        if (errorStr.isEmpty() && reply->error() != QNetworkReply::NoError) {
            errorStr = reply->errorString();
        }
        emit uploadFinished(requestId, success, errorStr);
    });
}
