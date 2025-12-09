#include "UdpController.h"
#include "Config/SirenConfig.h"
#include <QDebug>
#include <QNetworkInterface>
#include <QJsonDocument>
#include <QJsonObject>

#ifdef EMSCRIPTEN
    #define USE_WEBSOCKET 1
#else
    #define USE_WEBSOCKET 0
#endif

UdpController::UdpController(QObject *parent)
    : QObject(parent)
    , m_udpSocket(nullptr)
    , m_webSocket(nullptr)
    , m_address(QStringLiteral("192.168.1.101"))
    , m_port(4443)
    , m_receivePort(4444)
    , m_connected(false)
    , m_useWebSocket(USE_WEBSOCKET)
    , m_targetMachine(MachineType::LinuxMaitre)
{
    if (m_useWebSocket) {
        m_webSocket = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);
        connect(m_webSocket, &QWebSocket::connected, this, &UdpController::onWebSocketConnected);
        connect(m_webSocket, &QWebSocket::disconnected, this, &UdpController::onWebSocketDisconnected);
        connect(m_webSocket, &QWebSocket::binaryMessageReceived,
                this, &UdpController::onWebSocketBinaryMessageReceived);
        connect(m_webSocket, &QWebSocket::textMessageReceived,
                this, &UdpController::onWebSocketTextMessageReceived);
        connect(m_webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
                this, &UdpController::onWebSocketError);
    } else {
        m_udpSocket = new QUdpSocket(this);
        connect(m_udpSocket, &QUdpSocket::readyRead, this, &UdpController::onUdpReadyRead);
    }
}

UdpController::~UdpController()
{
    disconnectFromHost();
}

void UdpController::setAddress(const QString &address)
{
    if (m_address != address) {
        m_address = address;
        m_targetAddress = QHostAddress(address);
        emit addressChanged(m_address);
    }
}

void UdpController::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged(m_port);
    }
}

void UdpController::initialize()
{
    if (m_useWebSocket) {
        // For WebAssembly, connect to WebSocket proxy server
        QString wsUrl = QStringLiteral("ws://localhost:8006/udp-proxy");
        setupWebSocket(wsUrl);
    } else {
        // For desktop, setup UDP socket
        setupUdpSocket(m_receivePort);
    }
}

void UdpController::connectToHost(const QString &address, int port)
{
    setAddress(address);
    setPort(port);
    initialize();
}

void UdpController::disconnectFromHost()
{
    if (m_webSocket && m_webSocket->state() == QAbstractSocket::ConnectedState) {
        m_webSocket->close();
    }
    if (m_udpSocket) {
        m_udpSocket->close();
    }
    if (m_connected) {
        m_connected = false;
        emit connectedChanged(m_connected);
    }
}

void UdpController::setupUdpSocket(int receivePort)
{
    if (!m_udpSocket) {
        return;
    }
    
    if (m_udpSocket->bind(QHostAddress::AnyIPv4, receivePort, QUdpSocket::ShareAddress)) {
        qDebug() << "[UdpController] UDP socket bound to port" << receivePort;
        if (!m_connected) {
            m_connected = true;
            emit connectedChanged(m_connected);
        }
    } else {
        qWarning() << "[UdpController] Failed to bind UDP socket to port" << receivePort
                   << ":" << m_udpSocket->errorString();
        emit errorOccurred(QStringLiteral("Failed to bind UDP socket: %1").arg(m_udpSocket->errorString()));
    }
}

void UdpController::setupWebSocket(const QString &wsUrl)
{
    if (!m_webSocket) {
        return;
    }
    
    qDebug() << "[UdpController] Connecting to WebSocket proxy:" << wsUrl;
    m_webSocket->open(QUrl(wsUrl));
}

unsigned char UdpController::calculateBCC(const QByteArray &data)
{
    if (data.size() < 3) {
        return 0;
    }
    
    unsigned char bcc = static_cast<unsigned char>(data[3]);
    for (int i = 4; i < 10 && i < data.size(); ++i) {
        bcc ^= static_cast<unsigned char>(data[i]);
    }
    return bcc;
}

QByteArray UdpController::buildPacket(const QByteArray &data)
{
    QByteArray packet(10, 0x00);
    
    // Copy data (max 7 bytes, starting at position 3)
    int dataSize = qMin(data.size(), 7);
    for (int i = 0; i < dataSize; ++i) {
        packet[i + 3] = data[i];
    }
    
    // Calculate BCC (XOR of bytes 3-9)
    unsigned char bcc = packet[3];
    for (int i = 4; i < 10; ++i) {
        bcc ^= static_cast<unsigned char>(packet[i]);
    }
    
    // Set packet header
    packet[0] = 10;        // Length
    packet[1] = bcc;       // BCC checksum
    // Bytes 2-9 already set (data or zeros)
    
    return packet;
}

void UdpController::sendPacket(const QByteArray &packet)
{
    if (m_useWebSocket) {
        // Send via WebSocket proxy
        if (m_webSocket && m_webSocket->state() == QAbstractSocket::ConnectedState) {
            QJsonObject json;
            json[QStringLiteral("type")] = QStringLiteral("udp_send");
            json[QStringLiteral("address")] = m_address;
            json[QStringLiteral("port")] = m_port;
            json[QStringLiteral("data")] = QString::fromLatin1(packet.toHex());
            
            QJsonDocument doc(json);
            m_webSocket->sendTextMessage(QString::fromUtf8(doc.toJson()));
        } else {
            qWarning() << "[UdpController] WebSocket not connected";
            emit errorOccurred(QStringLiteral("WebSocket not connected"));
        }
    } else {
        // Send via UDP directly
        if (m_udpSocket && m_targetAddress.isNull() == false) {
            qint64 sent = m_udpSocket->writeDatagram(packet, m_targetAddress, m_port);
            if (sent != packet.size()) {
                qWarning() << "[UdpController] Failed to send UDP packet:" << m_udpSocket->errorString();
                emit errorOccurred(QStringLiteral("Failed to send UDP packet: %1").arg(m_udpSocket->errorString()));
            }
        }
    }
}

void UdpController::sendCommand(unsigned char cmd, const QByteArray &data)
{
    QByteArray commandData;
    commandData.append(static_cast<char>(cmd));
    commandData.append(data);
    
    QByteArray packet = buildPacket(commandData);
    sendPacket(packet);
}

void UdpController::sendCommandToMachine(MachineType machine, unsigned char cmd, const QByteArray &data)
{
    QString ip = SirenConfig::ipAddressForMachineType(machine);
    setAddress(ip);
    m_targetMachine = machine;
    sendCommand(cmd, data);
}

void UdpController::sendAskSynchro(MachineType machine)
{
    sendCommandToMachine(machine, UdpCommands::ASKSYNCHRO);
}

void UdpController::sendNewList(MachineType machine, int listIndex)
{
    QByteArray data;
    data.append(static_cast<char>(listIndex));
    sendCommandToMachine(machine, UdpCommands::NEWLIST, data);
}

void UdpController::sendBoucle(MachineType machine, bool enabled)
{
    QByteArray data;
    data.append(static_cast<char>(enabled ? 1 : 0));
    sendCommandToMachine(machine, UdpCommands::BOUCLE, data);
}

void UdpController::sendStart(MachineType machine)
{
    sendCommandToMachine(machine, UdpCommands::ST);
}

void UdpController::sendStop(MachineType machine)
{
    sendCommandToMachine(machine, UdpCommands::STOP);
}

void UdpController::sendReset(MachineType machine)
{
    sendCommandToMachine(machine, UdpCommands::RESET);
}

void UdpController::sendReverse(MachineType machine, bool enabled)
{
    QByteArray data;
    data.append(static_cast<char>(enabled ? 1 : 0));
    sendCommandToMachine(machine, UdpCommands::REVERSE, data);
}

void UdpController::setSpeed(MachineType machine, int speed)
{
    QByteArray data;
    data.append(static_cast<char>(speed));
    sendCommandToMachine(machine, UdpCommands::SETSPEED, data);
}

void UdpController::setTranspo(MachineType machine, int transpo)
{
    QByteArray data;
    data.append(static_cast<char>(transpo));
    sendCommandToMachine(machine, UdpCommands::TRANSPO, data);
}

void UdpController::setVolume(MachineType machine, int volume)
{
    QByteArray data;
    data.append(static_cast<char>(volume));
    sendCommandToMachine(machine, UdpCommands::VOLUME, data);
}

void UdpController::setMute(MachineType machine, bool muted)
{
    QByteArray data;
    data.append(static_cast<char>(muted ? 1 : 0));
    sendCommandToMachine(machine, UdpCommands::MUTE, data);
}

void UdpController::setVolumeGeneral(int volume)
{
    QByteArray data;
    data.append(static_cast<char>(volume));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::VOLUMEGENE, data);
}

void UdpController::onUdpReadyRead()
{
    if (!m_udpSocket) {
        return;
    }
    
    while (m_udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<int>(m_udpSocket->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort;
        
        qint64 read = m_udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);
        if (read > 0) {
            emit dataReceived(datagram, sender.toString(), senderPort);
        }
    }
}

void UdpController::onWebSocketConnected()
{
    qDebug() << "[UdpController] WebSocket connected";
    m_connected = true;
    emit connectedChanged(m_connected);
}

void UdpController::onWebSocketDisconnected()
{
    qDebug() << "[UdpController] WebSocket disconnected";
    m_connected = false;
    emit connectedChanged(m_connected);
}

void UdpController::onWebSocketBinaryMessageReceived(const QByteArray &message)
{
    // Parse WebSocket message format (assumes JSON with data field)
    emit dataReceived(message, m_address, m_port);
}

void UdpController::onWebSocketTextMessageReceived(const QString &message)
{
    // Parse JSON message from WebSocket proxy
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8(), &error);
    
    if (error.error != QJsonParseError::NoError) {
        qWarning() << "[UdpController] Failed to parse WebSocket message:" << error.errorString();
        return;
    }
    
    QJsonObject json = doc.object();
    if (json[QStringLiteral("type")].toString() == QStringLiteral("udp_receive")) {
        QString dataHex = json[QStringLiteral("data")].toString();
        QByteArray data = QByteArray::fromHex(dataHex.toLatin1());
        QString fromAddress = json[QStringLiteral("address")].toString();
        int fromPort = json[QStringLiteral("port")].toInt();
        
        emit dataReceived(data, fromAddress, fromPort);
    }
}

void UdpController::onWebSocketError(QAbstractSocket::SocketError error)
{
    QString errorString = m_webSocket ? m_webSocket->errorString() : QStringLiteral("Unknown error");
    qWarning() << "[UdpController] WebSocket error:" << error << errorString;
    emit errorOccurred(QStringLiteral("WebSocket error: %1").arg(errorString));
}


