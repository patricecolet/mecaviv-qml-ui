#include "simpletestgeometry.h"
#include <QDebug>
#include <QVector3D>

SimpleTestGeometry::SimpleTestGeometry()
{
    qDebug() << "SimpleTestGeometry constructor";
    
    // Quad simple : 4 vertices
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    Vertex vertices[] = {
        {-0.5f, -0.5f, 0.0f,  0.0f, 0.0f, 1.0f},  // Bas gauche
        { 0.5f, -0.5f, 0.0f,  0.0f, 0.0f, 1.0f},  // Bas droite
        { 0.5f,  0.5f, 0.0f,  0.0f, 0.0f, 1.0f},  // Haut droite
        {-0.5f,  0.5f, 0.0f,  0.0f, 0.0f, 1.0f}   // Haut gauche
    };
    
    quint32 indices[] = {0, 1, 2,  0, 2, 3};  // 2 triangles
    
    QByteArray vertexBuffer(reinterpret_cast<char*>(vertices), sizeof(vertices));
    QByteArray indexBuffer(reinterpret_cast<char*>(indices), sizeof(indices));
    
    qDebug() << "Setting up geometry - vertexBuffer:" << vertexBuffer.size() 
             << "indexBuffer:" << indexBuffer.size();
    
    setStride(sizeof(Vertex));
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    setBounds(QVector3D(-0.5f, -0.5f, 0.0f), QVector3D(0.5f, 0.5f, 0.0f));
    
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic, 0,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic, 12,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic, 0,
                 QQuick3DGeometry::Attribute::U32Type);
    
    qDebug() << "Geometry configured, calling update()";
    update();
    qDebug() << "Geometry ready";
}

