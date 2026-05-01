#ifndef SSHCONTROLLER_H
#define SSHCONTROLLER_H

#include <QObject>
#include <QString>
#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include "Config/MachineType.h"

// Wraps HTTP calls to the Node.js backend (default localhost:8005). The
// backend's /api/ssh/{execute,download,upload} endpoints proxy SSH operations
// to the various sirens. All methods are async — pass a requestId to correlate
// the *Finished signals with the call that produced them.
class SshController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString backendUrl READ backendUrl WRITE setBackendUrl NOTIFY backendUrlChanged)

public:
    explicit SshController(QObject *parent = nullptr);

    QString backendUrl() const { return m_backendUrl; }
    void setBackendUrl(const QString &url);

    Q_INVOKABLE void executeCommand(int machineType, const QString &command, const QString &requestId);
    Q_INVOKABLE void downloadFile(int machineType, const QString &remotePath, const QString &requestId);
    Q_INVOKABLE void uploadFile(int machineType, const QString &remotePath, const QString &content, const QString &requestId);

signals:
    void backendUrlChanged(const QString &url);
    void commandFinished(const QString &requestId, bool success, const QString &output, const QString &error);
    void downloadFinished(const QString &requestId, bool success, const QString &content, const QString &error);
    void uploadFinished(const QString &requestId, bool success, const QString &error);

private:
    static QString machineTypeToString(int machineType);
    void postJson(const QString &path, const QByteArray &body,
                  std::function<void(QNetworkReply*)> handler);

    QNetworkAccessManager *m_network;
    QString m_backendUrl;
};

#endif
