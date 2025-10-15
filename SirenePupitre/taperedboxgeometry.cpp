#include "taperedboxgeometry.h"
#include <QVector>
#include <QVector3D>
#include <QDebug>

TaperedBoxGeometry::TaperedBoxGeometry(QQuick3DObject *parent)
    : QQuick3DGeometry(parent)
{
    qDebug() << "TaperedBoxGeometry constructor";
    
    // Cube 3D : 8 vertices, 6 faces (12 triangles)
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    const float w = 50.0f;  // Demi-largeur
    const float h = 50.0f;  // Demi-hauteur
    const float d = 50.0f;  // Demi-profondeur
    
    Vertex vertices[] = {
        // Face avant (Z+)
        {-w, -h,  d,  0.0f, 0.0f, 1.0f},  // 0: bas-gauche-avant
        { w, -h,  d,  0.0f, 0.0f, 1.0f},  // 1: bas-droite-avant
        { w,  h,  d,  0.0f, 0.0f, 1.0f},  // 2: haut-droite-avant
        {-w,  h,  d,  0.0f, 0.0f, 1.0f},  // 3: haut-gauche-avant
        // Face arrière (Z-)
        {-w, -h, -d,  0.0f, 0.0f, -1.0f}, // 4: bas-gauche-arrière
        { w, -h, -d,  0.0f, 0.0f, -1.0f}, // 5: bas-droite-arrière
        { w,  h, -d,  0.0f, 0.0f, -1.0f}, // 6: haut-droite-arrière
        {-w,  h, -d,  0.0f, 0.0f, -1.0f}, // 7: haut-gauche-arrière
    };
    
    // 12 triangles (6 faces × 2 triangles)
    quint32 indices[] = {
        0, 1, 2,  0, 2, 3,  // Face avant (Z+)
        5, 4, 7,  5, 7, 6,  // Face arrière (Z-)
        4, 0, 3,  4, 3, 7,  // Face gauche (X-)
        1, 5, 6,  1, 6, 2,  // Face droite (X+)
        3, 2, 6,  3, 6, 7,  // Face haut (Y+)
        4, 5, 1,  4, 1, 0   // Face bas (Y-)
    };
    
    QByteArray vertexBuffer(reinterpret_cast<char*>(vertices), sizeof(vertices));
    QByteArray indexBuffer(reinterpret_cast<char*>(indices), sizeof(indices));
    
    qDebug() << "Setting up geometry - vertexBuffer:" << vertexBuffer.size() 
             << "indexBuffer:" << indexBuffer.size();
    
    setStride(sizeof(Vertex));
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    setBounds(QVector3D(-50.0f, -50.0f, -50.0f), QVector3D(50.0f, 50.0f, 50.0f));
    
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

void TaperedBoxGeometry::setSustainHeight(float height)
{
    if (qFuzzyCompare(m_sustainHeight, height))
        return;
    m_sustainHeight = height;
    emit sustainHeightChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setReleaseHeight(float height)
{
    if (qFuzzyCompare(m_releaseHeight, height))
        return;
    m_releaseHeight = height;
    emit releaseHeightChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setReleaseSegments(int segments)
{
    if (m_releaseSegments == segments)
        return;
    m_releaseSegments = qMax(1, segments);
    emit releaseSegmentsChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setWidth(float w)
{
    if (qFuzzyCompare(m_width, w))
        return;
    m_width = w;
    emit widthChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setDepth(float d)
{
    if (qFuzzyCompare(m_depth, d))
        return;
    m_depth = d;
    emit depthChanged();
    updateGeometry();
}

void TaperedBoxGeometry::updateGeometry()
{
    // Ne rien faire pour l'instant - la géométrie est hardcodée dans le constructeur
    qDebug() << "updateGeometry() called - geometry is static for now";
}
