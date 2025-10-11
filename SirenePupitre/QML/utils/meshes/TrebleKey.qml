import QtQuick
import QtQuick3D

Node {
    id: node

    // Resources
    PrincipledMaterial {
        id: wire_224198087_material
        objectName: "wire_224198087"
        baseColor: "#ffcccccc"
    }

    // Nodes:
    Node {
        id: trebleKey_obj
        objectName: "TrebleKey.obj"
        Model {
            id: objeto_Inteligente_de_Vetor
            objectName: "Objeto_Inteligente_de_Vetor"
            source: "meshes/objeto_Inteligente_de_Vetor_mesh.mesh"
            materials: [
                wire_224198087_material
            ]
        }
    }

    // Animations:
}
