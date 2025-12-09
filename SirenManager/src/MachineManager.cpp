#include "MachineManager.h"

MachineManager::MachineManager(QObject *parent)
    : QObject(parent)
{
}

bool MachineManager::isValidMachineType(MachineType machineType)
{
    return machineType >= MachineType::LinuxMaitre && machineType <= MachineType::Pavillon2;
}


