#ifndef UDPCONTROLLER_H
#define UDPCONTROLLER_H

#include <QObject>
#include <QByteArray>
#include <QString>
#include <QUdpSocket>
#include <QWebSocket>
#include <QHostAddress>
#include "Config/MachineType.h"

class UdpController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString address READ address WRITE setAddress NOTIFY addressChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)

public:
    explicit UdpController(QObject *parent = nullptr);
    ~UdpController();

    // Properties
    bool isConnected() const { return m_connected; }
    QString address() const { return m_address; }
    void setAddress(const QString &address);
    int port() const { return m_port; }
    void setPort(int port);

    // UDP Command methods (Q_INVOKABLE for QML)
    Q_INVOKABLE void sendCommand(unsigned char cmd, const QByteArray &data = QByteArray());
    Q_INVOKABLE void sendCommandToMachine(MachineType machine, unsigned char cmd, const QByteArray &data = QByteArray());
    
    // Convenience methods for common commands
    Q_INVOKABLE void sendAskSynchro(MachineType machine = MachineType::LinuxMaitre);
    Q_INVOKABLE void sendNewList(MachineType machine, int listIndex);
    Q_INVOKABLE void sendBoucle(MachineType machine, bool enabled);
    Q_INVOKABLE void sendStart(MachineType machine);
    Q_INVOKABLE void sendStop(MachineType machine);
    Q_INVOKABLE void sendReset(MachineType machine);
    Q_INVOKABLE void sendReverse(MachineType machine, bool enabled);
    Q_INVOKABLE void setSpeed(MachineType machine, int speed);
    Q_INVOKABLE void setTranspo(MachineType machine, int transpo);
    Q_INVOKABLE void setVolume(MachineType machine, int volume);
    Q_INVOKABLE void setMute(MachineType machine, bool muted);
    Q_INVOKABLE void setVolumeGeneral(int volume);
    
    // Initialize connection
    Q_INVOKABLE void initialize();
    Q_INVOKABLE void connectToHost(const QString &address, int port);
    Q_INVOKABLE void disconnectFromHost();

signals:
    void connectedChanged(bool connected);
    void addressChanged(const QString &address);
    void portChanged(int port);
    void dataReceived(const QByteArray &data, const QString &fromAddress, int fromPort);
    void errorOccurred(const QString &errorString);

private slots:
    void onUdpReadyRead();
    void onWebSocketConnected();
    void onWebSocketDisconnected();
    void onWebSocketBinaryMessageReceived(const QByteArray &message);
    void onWebSocketTextMessageReceived(const QString &message);
    void onWebSocketError(QAbstractSocket::SocketError error);

private:
    // Calculate BCC checksum (XOR of bytes 3-9)
    unsigned char calculateBCC(const QByteArray &data);
    
    // Build UDP packet with format: [length(1)][BCC(2)][data(3-10)]
    QByteArray buildPacket(const QByteArray &data);
    
    // Send packet
    void sendPacket(const QByteArray &packet);
    
    // Setup UDP socket (desktop)
    void setupUdpSocket(int receivePort);
    
    // Setup WebSocket (WebAssembly)
    void setupWebSocket(const QString &wsUrl);

private:
    QUdpSocket *m_udpSocket;
    QWebSocket *m_webSocket;
    QString m_address;
    int m_port;
    int m_receivePort;
    bool m_connected;
    bool m_useWebSocket; // true for WebAssembly, false for desktop
    QHostAddress m_targetAddress;
    MachineType m_targetMachine;
};

#endif // UDPCONTROLLER_H


