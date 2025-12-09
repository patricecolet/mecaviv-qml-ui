import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager 1.0

Rectangle {
    id: root
    
    property var selectedMachines: []
    property bool selectAll: false
    
    signal machineToggled(var machineType, bool selected)
    signal selectAllMachines()
    signal deselectAllMachines()
    
    color: "#1e1e1e"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        Text {
            Layout.fillWidth: true
            text: "Sélection des Machines"
            color: "#FFFFFF"
            font.pixelSize: 16
            font.bold: true
        }
        
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: "Tout sélectionner"
                onClicked: root.selectAllMachines()
            }
            
            Button {
                text: "Tout désélectionner"
                onClicked: root.deselectAllMachines()
            }
        }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            GridLayout {
                width: root.width - 20
                columns: 2
                rowSpacing: 5
                columnSpacing: 10
                
                MachineCheckBox {
                    label: "Linux Maître"
                    machineType: MachineType.LinuxMaitre
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "Raspberry Clic"
                    machineType: MachineType.RaspberryClic
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S1"
                    machineType: MachineType.S1
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S2"
                    machineType: MachineType.S2
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S3"
                    machineType: MachineType.S3
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S4"
                    machineType: MachineType.S4
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S5"
                    machineType: MachineType.S5
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S6"
                    machineType: MachineType.S6
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "S7"
                    machineType: MachineType.S7
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "Voiture A"
                    machineType: MachineType.VoitureA
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "Voiture B"
                    machineType: MachineType.VoitureB
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "Pavillon 1"
                    machineType: MachineType.Pavillon1
                    onToggled: root.machineToggled(machineType, checked)
                }
                
                MachineCheckBox {
                    label: "Pavillon 2"
                    machineType: MachineType.Pavillon2
                    onToggled: root.machineToggled(machineType, checked)
                }
            }
        }
    }
    
    component MachineCheckBox: CheckBox {
        property var machineType
        property string label: ""
        text: label
    }
}
