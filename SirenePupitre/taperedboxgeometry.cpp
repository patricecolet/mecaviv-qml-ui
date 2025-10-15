#include "taperedboxgeometry.h"
#include <QVector>
#include <QVector3D>
#include <QDebug>

TaperedBoxGeometry::TaperedBoxGeometry(QQuick3DObject *parent)
    : QQuick3DGeometry(parent)
{
    qDebug() << "TaperedBoxGeometry constructor";
    
    // Cube 3D + pyramide : cube variable + pyramide hauteur fixe absolue
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    const float w = 50.0f;  // Demi-largeur
    const float h = 50.0f;  // Demi-hauteur du cube
    const float d = 50.0f;  // Demi-profondeur
    
    // Pyramide : hauteur ajustée pour avoir m_releaseHeight en unités absolues après scale
    // Scale QML = sustainHeight * cubeSize / 20
    // Pour hauteur absolue = m_releaseHeight : hPyramid_normalized = m_releaseHeight / scale
    const float cubeSize = 0.4f;
    const float scale = m_sustainHeight * cubeSize / 20.0f;
    const float hPyramid = (scale > 0) ? (m_releaseHeight / scale) : 20.0f;
    
    const float yBot = -h;            // Bas du cube
    const float yTop = h;             // Haut du cube = base de la pyramide
    const float yPeak = h + hPyramid; // Sommet de la pyramide
    
    // 13 vertices : 8 pour le cube + 5 pour la pyramide
    Vertex vertices[] = {
        // === CUBE (sustain) - 8 vertices ===
        // Face avant (Z+)
        {-w, yBot,  d,  0.0f, 0.0f, 1.0f},  // 0: bas-gauche-avant
        { w, yBot,  d,  0.0f, 0.0f, 1.0f},  // 1: bas-droite-avant
        { w, yTop,  d,  0.0f, 0.0f, 1.0f},  // 2: haut-droite-avant
        {-w, yTop,  d,  0.0f, 0.0f, 1.0f},  // 3: haut-gauche-avant
        // Face arrière (Z-)
        {-w, yBot, -d,  0.0f, 0.0f, -1.0f}, // 4: bas-gauche-arrière
        { w, yBot, -d,  0.0f, 0.0f, -1.0f}, // 5: bas-droite-arrière
        { w, yTop, -d,  0.0f, 0.0f, -1.0f}, // 6: haut-droite-arrière
        {-w, yTop, -d,  0.0f, 0.0f, -1.0f}, // 7: haut-gauche-arrière
        
        // === PYRAMIDE (release) - 5 vertices ===
        // Base de la pyramide (= haut du cube, nouvelles normales)
        {-w, yTop,  d,  0.0f, 1.0f, 0.0f},  // 8: base-gauche-avant
        { w, yTop,  d,  0.0f, 1.0f, 0.0f},  // 9: base-droite-avant
        { w, yTop, -d,  0.0f, 1.0f, 0.0f},  // 10: base-droite-arrière
        {-w, yTop, -d,  0.0f, 1.0f, 0.0f},  // 11: base-gauche-arrière
        // Sommet de la pyramide
        {0.0f, yPeak, 0.0f,  0.0f, 1.0f, 0.0f}  // 12: sommet
    };
    
    // 10 triangles (cube sans face haut) + 4 triangles (pyramide) = 14 triangles
    quint32 indices[] = {
        // === CUBE (sustain) - 5 faces ===
        0, 1, 2,  0, 2, 3,  // Face avant (Z+)
        5, 4, 7,  5, 7, 6,  // Face arrière (Z-)
        4, 0, 3,  4, 3, 7,  // Face gauche (X-)
        1, 5, 6,  1, 6, 2,  // Face droite (X+)
        // Pas de face haut (remplacée par la base de la pyramide)
        4, 5, 1,  4, 1, 0,  // Face bas (Y-)
        
        // === PYRAMIDE (release) - 4 faces ===
        8, 9, 12,   // Face avant
        9, 10, 12,  // Face droite
        10, 11, 12, // Face arrière
        11, 8, 12   // Face gauche
    };
    
    QByteArray vertexBuffer(reinterpret_cast<char*>(vertices), sizeof(vertices));
    QByteArray indexBuffer(reinterpret_cast<char*>(indices), sizeof(indices));
    
    qDebug() << "Setting up geometry - vertexBuffer:" << vertexBuffer.size() 
             << "indexBuffer:" << indexBuffer.size();
    
    setStride(sizeof(Vertex));
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    // Bounds : cube (-50 à +50) + pyramide (+50 à +70)
    setBounds(QVector3D(-50.0f, -50.0f, -50.0f), QVector3D(50.0f, 70.0f, 50.0f));
    
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
    qDebug() << "updateGeometry() - sustain:" << m_sustainHeight << "release:" << m_releaseHeight;
    
    // Même logique que le constructeur
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    const float w = 50.0f;
    const float h = 50.0f;
    const float d = 50.0f;
    
    // Pyramide : hauteur ajustée pour avoir m_releaseHeight en absolu
    const float cubeSize = 0.4f;
    const float scale = m_sustainHeight * cubeSize / 20.0f;
    const float hPyramid = (scale > 0) ? (m_releaseHeight / scale) : 20.0f;
    
    const float yBot = -h;
    const float yTop = h;
    const float yPeak = h + hPyramid;
    
    // 13 vertices
    Vertex vertices[] = {
        // CUBE
        {-w, yBot,  d,  0.0f, 0.0f, 1.0f},
        { w, yBot,  d,  0.0f, 0.0f, 1.0f},
        { w, yTop,  d,  0.0f, 0.0f, 1.0f},
        {-w, yTop,  d,  0.0f, 0.0f, 1.0f},
        {-w, yBot, -d,  0.0f, 0.0f, -1.0f},
        { w, yBot, -d,  0.0f, 0.0f, -1.0f},
        { w, yTop, -d,  0.0f, 0.0f, -1.0f},
        {-w, yTop, -d,  0.0f, 0.0f, -1.0f},
        // PYRAMIDE
        {-w, yTop,  d,  0.0f, 1.0f, 0.0f},
        { w, yTop,  d,  0.0f, 1.0f, 0.0f},
        { w, yTop, -d,  0.0f, 1.0f, 0.0f},
        {-w, yTop, -d,  0.0f, 1.0f, 0.0f},
        {0.0f, yPeak, 0.0f,  0.0f, 1.0f, 0.0f}
    };
    
    quint32 indices[] = {
        0, 1, 2,  0, 2, 3,
        5, 4, 7,  5, 7, 6,
        4, 0, 3,  4, 3, 7,
        1, 5, 6,  1, 6, 2,
        4, 5, 1,  4, 1, 0,
        8, 9, 12,
        9, 10, 12,
        10, 11, 12,
        11, 8, 12
    };
    
    m_vertexBuffer = QByteArray(reinterpret_cast<char*>(vertices), sizeof(vertices));
    m_indexBuffer = QByteArray(reinterpret_cast<char*>(indices), sizeof(indices));
    
    setVertexData(m_vertexBuffer);
    setIndexData(m_indexBuffer);
    setBounds(QVector3D(-w, yBot, -d), QVector3D(w, yPeak, d));
    
    update();
}
