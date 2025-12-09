#ifndef SIRENCONFIG_H
#define SIRENCONFIG_H

#include <QString>
#include <QStringList>
#include "MachineType.h"

// UDP Command codes
namespace UdpCommands {
    const unsigned char ASKSYNCHRO = 0x01;
    const unsigned char NEWLIST = 0x02;
    const unsigned char BOUCLE = 0x03;
    const unsigned char ST = 0x04;
    const unsigned char ISSYNCHRO = 0x05;
    const unsigned char STOP = 0x06;
    const unsigned char SEQSELECTED = 0x07;
    const unsigned char RESET = 0x08;
    const unsigned char REVERSE = 0x09;
    const unsigned char SETSPEED = 0x0A;
    const unsigned char TRANSPO = 0x0B;
    const unsigned char PCHIIT = 0x0C;
    const unsigned char AUTOMATING = 0x0D;
    const unsigned char SIRENIUM = 0x0E;
    const unsigned char VOLUME = 0x0F;
    const unsigned char VOLETACTIF = 0x10;
    const unsigned char MUTE = 0x11;
    const unsigned char MIDIIN = 0x12;
    const unsigned char SYNCHRO = 0x13;
    const unsigned char SETKEB = 0x14;
    const unsigned char SETVOLET = 0x15;
    const unsigned char SOURDINE = 0x16;
    const unsigned char PATCHSOURD = 0x17;
    const unsigned char LED = 0x18;
    const unsigned char LEDTROMPE = 0x19;
    const unsigned char VOITURE = 0x1A;
    const unsigned char TROMPEVOL = 0x1B;
    const unsigned char TROMPELESLI = 0x1C;
    const unsigned char TROMPEONOFF = 0x1D;
    const unsigned char TROMPEPOINT0 = 0x1E;
    const unsigned char VOLUMEGENE = 0x1F;
    const unsigned char REPONSESIRE = 0x20;
    const unsigned char TRAMPRESENCE = 0x21;
    const unsigned char RECVST = 0x22;
    const unsigned char SIRSELECT = 0x23;
    const unsigned char DEFRET = 0x24;
    const unsigned char TOURELLE = 0x25;
    const unsigned char IS_SIRENIUM = 0x26;
    const unsigned char SET_CLIC_LAT = 0x27;
    const unsigned char SET_CLIC_BOUCLE = 0x28;
    const unsigned char SET_PRESETLED1 = 0x30;
    const unsigned char SET_PRESETLED2 = 0x31;
    const unsigned char SET_PRESETLED3 = 0x32;
    const unsigned char SET_PRESETLED4 = 0x33;
    const unsigned char GET_SYSTEM_INFO = 0x40;
}

class SirenConfig
{
public:
    // Machine IP Addresses
    static QString ipAddressForMachineType(MachineType machineType);
    static QString nameForMachineType(MachineType machineType);
    
    // Paths
    static QString midiPathForMachineType(MachineType machineType);
    static QString playlistPathForMachineType(MachineType machineType);
    static QString derniereListePathForMachineType(MachineType machineType);
    
    // Authentication
    static QString sshUsernameForMachineType(MachineType machineType);
    static QString sshPasswordForMachineType(MachineType machineType);
    static QString ftpUsernameForMachineType(MachineType machineType);
    static QString ftpPasswordForMachineType(MachineType machineType);
    static QString sshKeyPath();
    
    // Lists
    static QStringList allMachineIPs();
    static QStringList allMachineNames();
    
    // Network Ports
    static constexpr int PortSSH = 22;
    static constexpr int PortFTP = 21;
    static constexpr int PortUDP = 4443;
    
    // File Extensions
    static const QString ExtensionPlaylist;
    static const QString ExtensionPlaylistAlt;
    static const QString ExtensionMIDI;
    static const QString ExtensionMIDIAlt;
    
    // Status Messages
    static const QString StatusReady;
    static const QString StatusRAMNA;
    static const QString StatusDiskNA;
    static const QString StatusLoading;
    static const QString StatusErrorConnection;
    static const QString StatusErrorSSHUnavailable;
    static const QString StatusErrorManagersNotInitialized;
    static const QString StatusErrorPlaylistPathUndefined;
};

#endif // SIRENCONFIG_H


