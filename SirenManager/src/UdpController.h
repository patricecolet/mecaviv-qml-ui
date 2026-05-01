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
    Q_INVOKABLE void sendST(MachineType machine, bool state);
    Q_INVOKABLE void sendIsSynchro(MachineType machine, bool state);
    Q_INVOKABLE void sendSeqSelected(MachineType machine, int slotIndex);
    Q_INVOKABLE void reprendreAtIndex(MachineType machine, int slotIndex, int measure);
    Q_INVOKABLE void sendStop(MachineType machine);
    Q_INVOKABLE void sendReset(MachineType machine);
    Q_INVOKABLE void sendReverse(MachineType machine, bool enabled);
    Q_INVOKABLE void setSpeed(MachineType machine, int speed);
    Q_INVOKABLE void setTranspo(MachineType machine, int transpo);
    Q_INVOKABLE void setVolume(MachineType machine, int volume);
    Q_INVOKABLE void setMute(MachineType machine, bool muted);
    Q_INVOKABLE void setVolumeGeneral(int volume);

    // Maintenance view
    Q_INVOKABLE void sendSetKEB(int sirenIdx, int speed);       // sirenIdx 1..7
    Q_INVOKABLE void sendSetVolet(int sirenIdx, int value);     // sirenIdx 1..7
    Q_INVOKABLE void sendTranspoGlobal(int value);              // -64..+63
    Q_INVOKABLE void sendClicLatency(int value);
    Q_INVOKABLE void sendChangeVolet(MachineType siren, int valveIdx);  // valveIdx 0..3

    // Mixer view
    Q_INVOKABLE void sendSirenVolume(int sirenIdx, int value);  // sirenIdx 1..7, value 0..127
    Q_INVOKABLE void sendVolumeAll(QList<int> values);          // 7 values 0..127
    Q_INVOKABLE void sendMute(int sirenIdx, bool muted);        // sirenIdx 0..8 (0 = master)
    Q_INVOKABLE void sendSourdine(int sirenIdx, int type, int value);   // S1-S4 type=sub-ch, S5-S7 type 1=vol/2=timbre
    Q_INVOKABLE void sendLED(int ch, int numSourdine, int value);
    Q_INVOKABLE void sendLEDTrompe(int value);                  // for S8
    Q_INVOKABLE void sendVoletActif(int sirenIdx, int mask);    // 4-bit mask for which volets are active
    Q_INVOKABLE void sendLumiere(int side, int proj, int value); // side 0x9C/0x9D, proj 1/2

    // Controleur view — MIDI inject. channel 1..7, status is the MIDI status
    // byte (e.g. 0xB0 = CC, 0xE0 = pitch bend, 0x90 = note on).
    Q_INVOKABLE void sendMidiIn(int channel, int status, int data1, int data2);

    // Sirenium view
    Q_INVOKABLE void sendSirSelect(int sirenIdx, bool selected);  // 1..8
    Q_INVOKABLE void sendDefret(bool active);
    Q_INVOKABLE void sendAutomating(bool active);

    // Voitures + Pavillons
    Q_INVOKABLE void sendVoiture(int carIdx, int directionByte);
    Q_INVOKABLE void sendTourelle(int side, int sub, int value);  // generic CMD_TOURELLE
    Q_INVOKABLE void sendPchit(bool active);
    
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

    // Parsed Linux Maître responses (Player view)
    void sequenceInfoReceived(const QString &name, int totalSeconds);
    void timingUpdated(int currentSeconds);
    void runningStateChanged(bool running, int slotIndex);
    void loopStateChanged(bool active);
    void playlistSlotReceived(int slot, const QString &filename, bool isLoop, bool isChain);
    void slotLengthReceived(int slot, int lengthTicks);

    // Parsed Linux Maître responses (Maintenance view)
    // TRAMPRESENCE 0x21: per-siren KEB liveness + Trompe liveness (byte >= 5 = absent)
    void kebPresenceReceived(int sirenIdx, bool present);   // sirenIdx 1..7
    void trompePresenceReceived(bool present);
    // RECVST 0x22: per-siren motor state echo (1 = active, 0 = no response)
    void motorStateReceived(int sirenIdx, bool active);     // sirenIdx 1..7
    // 'LL' + idx + size + name: an entry of the playlist-files list on the master
    void playlistFileReceived(int index, const QString &filename);

    // Sirenium view feedback
    // CMD_IS_SIRENIUM 0x26: state + currently-played MIDI note + velocity
    void sireniumStateReceived(bool active, int midiNote, int velocity);
    // 'SE' + sirenIdx + state: selection state echo from firmware
    void sirenSelectionReceived(int sirenIdx, bool selected);

private slots:
    void parseIncomingData(const QByteArray &data, const QString &fromAddress, int fromPort);
    void onUdpReadyRead();
    void onWebSocketConnected();
    void onWebSocketDisconnected();
    void onWebSocketBinaryMessageReceived(const QByteArray &message);
    void onWebSocketTextMessageReceived(const QString &message);
    void onWebSocketError(QAbstractSocket::SocketError error);

private:
    // Build UDP packet matching legacy SireneControlMac SendUdp.m wire format.
    // Input is raw payload `[cmd, 0x04, 0x00, data...]`; output is the 10-byte
    // frame `[cmd, length=10, BCC, data×7]`. The 0x04/0x00 marker bytes get
    // overwritten by length and BCC. BCC = XOR of output bytes 4..9 (legacy
    // quirk: byte 3 is excluded — replicating firmware behavior).
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


