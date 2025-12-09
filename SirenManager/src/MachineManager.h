#ifndef MACHINEMANAGER_H
#define MACHINEMANAGER_H

#include <QObject>
#include "Config/MachineType.h"

class MachineManager : public QObject
{
    Q_OBJECT

public:
    explicit MachineManager(QObject *parent = nullptr);
    
    // Factory methods for creating managers for specific machines
    static bool isValidMachineType(MachineType machineType);
};

#endif // MACHINEMANAGER_H


