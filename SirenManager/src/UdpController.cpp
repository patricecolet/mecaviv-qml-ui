#include "UdpController.h"
#include "Config/SirenConfig.h"
#include <QDebug>
#include <QList>
#include <QLoggingCategory>
#include <QNetworkInterface>
#include <QJsonDocument>
#include <QJsonObject>

// Verbose UDP wire dump — silent by default. Enable with:
//   QT_LOGGING_RULES="sirenmanager.udp.debug=true" ./appSirenManager
Q_LOGGING_CATEGORY(udpLog, "sirenmanager.udp", QtWarningMsg)

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
    , m_port(8001)        // Default send port for Linux Maître (legacy AppDelegate.m:116)
    , m_receivePort(8000) // Local receive port (legacy: every SendUdp instance binds 8000)
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

    connect(this, &UdpController::dataReceived,
            this, &UdpController::parseIncomingData);
}

UdpController::~UdpController()
{
    disconnectFromHost();
}

void UdpController::setAddress(const QString &address)
{
    // Always update m_targetAddress: the constructor seeds m_address with a
    // default string but leaves m_targetAddress null, so an early-return on
    // m_address == address would leave us unable to send.
    m_targetAddress = QHostAddress(address);
    if (m_address != address) {
        m_address = address;
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
        qCInfo(udpLog) << "UDP socket bound to port" << receivePort
                       << "send target=" << m_address << ":" << m_port;
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

QByteArray UdpController::buildPacket(const QByteArray &data)
{
    QByteArray packet(10, 0x00);
    int copySize = qMin(data.size(), 10);
    for (int i = 0; i < copySize; ++i) {
        packet[i] = data[i];
    }

    unsigned char bcc = 0;
    for (int i = 4; i < 10; ++i) {
        bcc ^= static_cast<unsigned char>(packet[i]);
    }

    packet[1] = static_cast<char>(10);
    packet[2] = static_cast<char>(bcc);
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
            qCDebug(udpLog).noquote() << "TX" << sent << "B to"
                                      << m_address << ":" << m_port
                                      << "hex=" << packet.toHex(' ');
            if (sent != packet.size()) {
                qCWarning(udpLog) << "Failed to send UDP packet:" << m_udpSocket->errorString();
                emit errorOccurred(QStringLiteral("Failed to send UDP packet: %1").arg(m_udpSocket->errorString()));
            }
        } else {
            qCWarning(udpLog) << "Cannot send: socket="
                              << (m_udpSocket ? "ok" : "null")
                              << " target=" << m_address;
        }
    }
}

void UdpController::sendCommand(unsigned char cmd, const QByteArray &data)
{
    // Legacy convention: raw payload is [cmd, 0x04, 0x00, data...]; the 0x04
    // and 0x00 are clobbered by length and BCC inside buildPacket.
    QByteArray frame;
    frame.append(static_cast<char>(cmd));
    frame.append(static_cast<char>(0x04));
    frame.append(static_cast<char>(0x00));
    frame.append(data);

    QByteArray packet = buildPacket(frame);
    sendPacket(packet);
}

void UdpController::sendCommandToMachine(MachineType machine, unsigned char cmd, const QByteArray &data)
{
    // Legacy AppDelegate.m:116-123 uses different send ports per machine:
    //   Linux Maître → 8001, individual sirens S1–S7 → 1234.
    QString ip = SirenConfig::ipAddressForMachineType(machine);
    setAddress(ip);
    int sendPort = (machine == MachineType::LinuxMaitre) ? 8001 : 1234;
    setPort(sendPort);
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

void UdpController::sendST(MachineType machine, bool state)
{
    QByteArray data;
    data.append(static_cast<char>(state ? 1 : 0));
    sendCommandToMachine(machine, UdpCommands::ST, data);
}

void UdpController::sendIsSynchro(MachineType machine, bool state)
{
    QByteArray data;
    data.append(static_cast<char>(state ? 1 : 0));
    sendCommandToMachine(machine, UdpCommands::ISSYNCHRO, data);
}

void UdpController::sendSeqSelected(MachineType machine, int slotIndex)
{
    QByteArray data;
    data.append(static_cast<char>(slotIndex));
    sendCommandToMachine(machine, UdpCommands::SEQSELECTED, data);
}

void UdpController::reprendreAtIndex(MachineType machine, int slotIndex, int measure)
{
    // Legacy opcode 0x36: resume from given measure inside given slot.
    // Wire layout after framing: [0x36, 10, BCC, slot, m_be32(4), pad×2]
    QByteArray data;
    data.append(static_cast<char>(slotIndex));
    data.append(static_cast<char>((measure >> 24) & 0xFF));
    data.append(static_cast<char>((measure >> 16) & 0xFF));
    data.append(static_cast<char>((measure >> 8) & 0xFF));
    data.append(static_cast<char>(measure & 0xFF));
    sendCommandToMachine(machine, 0x36, data);
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

void UdpController::sendSetKEB(int sirenIdx, int speed)
{
    if (sirenIdx < 1 || sirenIdx > 7) return;
    QByteArray data;
    data.append(static_cast<char>(sirenIdx));
    data.append(static_cast<char>((speed >> 8) & 0xFF));
    data.append(static_cast<char>(speed & 0xFF));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::SETKEB, data);
}

void UdpController::sendSetVolet(int sirenIdx, int value)
{
    if (sirenIdx < 1 || sirenIdx > 7) return;
    QByteArray data;
    data.append(static_cast<char>(sirenIdx));
    data.append(static_cast<char>((value >> 8) & 0xFF));
    data.append(static_cast<char>(value & 0xFF));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::SETVOLET, data);
}

void UdpController::sendTranspoGlobal(int value)
{
    // Legacy encodes as (64 + signed value); receiver subtracts 64.
    QByteArray data;
    data.append(static_cast<char>((64 + value) & 0xFF));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::TRANSPO, data);
}

void UdpController::sendClicLatency(int value)
{
    // Legacy: { CMD_SET_CLIC_LAT, 0x04, 0x00, 0x0A, value } — the 0x0A is a
    // sub-selector replicated verbatim from SireneControlMac.
    QByteArray data;
    data.append(static_cast<char>(0x0A));
    data.append(static_cast<char>(value));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::SET_CLIC_LAT, data);
}

void UdpController::sendChangeVolet(MachineType siren, int valveIdx)
{
    // Legacy sends "Z000<mask>" UTF-8 directly to the target siren on port 1234.
    // After framing the wire shape is [Z, 10, BCC, '0', mask, 0, 0, 0, 0, 0],
    // so the payload (after the cmd + two clobbered marker bytes) is "0<mask>".
    if (valveIdx < 0 || valveIdx > 3) return;
    QByteArray data;
    data.append(static_cast<char>('0'));
    data.append(static_cast<char>(1 << valveIdx));
    sendCommandToMachine(siren, static_cast<unsigned char>('Z'), data);
}

void UdpController::sendSirenVolume(int sirenIdx, int value)
{
    if (sirenIdx < 1 || sirenIdx > 7) return;
    QByteArray data;
    data.append(static_cast<char>(sirenIdx));
    data.append(static_cast<char>(qBound(0, value, 127)));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::VOLUME, data);
}

void UdpController::sendVolumeAll(QList<int> values)
{
    // Legacy CMD_VOLUMEGENE: payload is 7 individual volumes (S1..S7), each 0..127.
    QByteArray data;
    for (int i = 0; i < 7; ++i) {
        int v = (i < values.size()) ? values[i] : 0;
        data.append(static_cast<char>(qBound(0, v, 127)));
    }
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::VOLUMEGENE, data);
}

void UdpController::sendMute(int sirenIdx, bool muted)
{
    // sirenIdx 0 = master (all sirens), 1..8 = individual (S1..S7 + Trompe S8)
    if (sirenIdx < 0 || sirenIdx > 8) return;
    QByteArray data;
    data.append(static_cast<char>(sirenIdx));
    data.append(static_cast<char>(muted ? 1 : 0));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::MUTE, data);
}

void UdpController::sendSourdine(int sirenIdx, int type, int value)
{
    if (sirenIdx < 1 || sirenIdx > 7) return;
    QByteArray data;
    data.append(static_cast<char>(sirenIdx));
    data.append(static_cast<char>(type));
    data.append(static_cast<char>(value));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::SOURDINE, data);
}

void UdpController::sendLED(int ch, int numSourdine, int value)
{
    QByteArray data;
    data.append(static_cast<char>(ch));
    data.append(static_cast<char>(numSourdine));
    data.append(static_cast<char>(value));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::LED, data);
}

void UdpController::sendLEDTrompe(int value)
{
    QByteArray data;
    data.append(static_cast<char>(value));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::LEDTROMPE, data);
}

void UdpController::sendVoletActif(int sirenIdx, int mask)
{
    if (sirenIdx < 1 || sirenIdx > 7) return;
    QByteArray data;
    data.append(static_cast<char>(sirenIdx));
    data.append(static_cast<char>(mask & 0x0F));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::VOLETACTIF, data);
}

void UdpController::sendLumiere(int side, int proj, int value)
{
    // Legacy CMD_TOURELLE: { 0x25, 0x06, 0x00, side(0x9C/0x9D), proj(0x01/0x02), value }
    QByteArray data;
    data.append(static_cast<char>(side));
    data.append(static_cast<char>(proj));
    data.append(static_cast<char>(value));
    sendCommandToMachine(MachineType::LinuxMaitre, UdpCommands::TOURELLE, data);
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

void UdpController::parseIncomingData(const QByteArray &data, const QString &fromAddress, int fromPort)
{
    qCDebug(udpLog).noquote() << "RX" << data.size() << "B from"
                              << fromAddress << ":" << fromPort
                              << "hex=" << data.toHex(' ');
    Q_UNUSED(fromAddress)
    Q_UNUSED(fromPort)
    if (data.isEmpty()) return;

    const unsigned char b0 = static_cast<unsigned char>(data[0]);

    // Per-slot tick length: [0x34, slot, len_be32]
    if (b0 == 0x34 && data.size() == 6) {
        int slot = static_cast<unsigned char>(data[1]);
        quint32 length =
              (static_cast<quint32>(static_cast<unsigned char>(data[2])) << 24)
            | (static_cast<quint32>(static_cast<unsigned char>(data[3])) << 16)
            | (static_cast<quint32>(static_cast<unsigned char>(data[4])) <<  8)
            |  static_cast<quint32>(static_cast<unsigned char>(data[5]));
        emit slotLengthReceived(slot, static_cast<int>(length));
        return;
    }

    if (data.size() < 2) return;
    const unsigned char b1 = static_cast<unsigned char>(data[1]);

    // 'PS' + slot + ? + B + E + filename: playlist slot push from Linux Maître.
    // Firmware always appends a trailing 0x00; strip it or macOS renders the
    // NUL glyph as a tofu-bar pattern next to the title.
    if (b0 == 'P' && b1 == 'S' && data.size() >= 6) {
        int slot = static_cast<unsigned char>(data[2]);
        bool isLoop  = (data[4] == '1');
        bool isChain = (data[5] == '1');
        QByteArray nameBytes = data.mid(6);
        while (!nameBytes.isEmpty() && nameBytes.endsWith('\0')) nameBytes.chop(1);
        QString filename = QString::fromUtf8(nameBytes);
        emit playlistSlotReceived(slot, filename, isLoop, isChain);
        return;
    }

    // 'SL' + min + sec + filename: current sequence length + name
    if (b0 == 'S' && b1 == 'L' && data.size() >= 4) {
        int min = static_cast<unsigned char>(data[2]);
        int sec = static_cast<unsigned char>(data[3]);
        QByteArray nameBytes = data.mid(4);
        while (!nameBytes.isEmpty() && nameBytes.endsWith('\0')) nameBytes.chop(1);
        QString name = QString::fromLatin1(nameBytes);
        // Legacy strips the file extension before display.
        int dotIdx = name.lastIndexOf(QLatin1Char('.'));
        if (dotIdx > 0) name = name.left(dotIdx);
        emit sequenceInfoReceived(name, min * 60 + sec);
        return;
    }

    // 'TI' + min + sec: live timing tick (slider position)
    if (b0 == 'T' && b1 == 'I' && data.size() >= 4) {
        int min = static_cast<unsigned char>(data[2]);
        int sec = static_cast<unsigned char>(data[3]);
        emit timingUpdated(min * 60 + sec);
        return;
    }

    // 'RB' + state: loop button state echo
    if (b0 == 'R' && b1 == 'B' && data.size() >= 3) {
        emit loopStateChanged(static_cast<unsigned char>(data[2]) != 0);
        return;
    }

    // 'RU' + running + slotIndex: running status + active slot
    if (b0 == 'R' && b1 == 'U' && data.size() >= 4) {
        bool running = static_cast<unsigned char>(data[2]) == 1;
        int slot = static_cast<unsigned char>(data[3]);
        emit runningStateChanged(running, slot);
        return;
    }

    // 'LL' + idx + size + name: a playlist file entry on the master.
    // Legacy uses 1-based idx, store map[idx-1] -> name.
    if (b0 == 'L' && b1 == 'L' && data.size() >= 5) {
        int idx = static_cast<unsigned char>(data[2]) - 1;
        QByteArray nameBytes = data.mid(4);
        while (!nameBytes.isEmpty() && nameBytes.endsWith('\0')) nameBytes.chop(1);
        emit playlistFileReceived(idx, QString::fromUtf8(nameBytes));
        return;
    }

    // TRAMPRESENCE 0x21: 10-byte heartbeat — bytes 1..7 are KEB S1..S7
    // liveness counters, byte 8 is Trompe. Any value >= 5 means absent.
    if (b0 == 0x21 && data.size() >= 10) {
        for (int i = 1; i <= 7; ++i) {
            bool present = static_cast<unsigned char>(data[i]) < 5;
            emit kebPresenceReceived(i, present);
        }
        emit trompePresenceReceived(static_cast<unsigned char>(data[8]) < 5);
        return;
    }

    // RECVST 0x22: 10-byte motor-state echo — bytes 1..7 indicate whether the
    // KEB drive on Sn is responding (1 = active, 0 = silent).
    if (b0 == 0x22 && data.size() >= 10) {
        for (int i = 1; i <= 7; ++i) {
            emit motorStateReceived(i, static_cast<unsigned char>(data[i]) == 0x01);
        }
        return;
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


