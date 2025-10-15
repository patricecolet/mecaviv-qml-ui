#include "taperedboxgeometry.h"
#include <QVector>
#include <QVector3D>
#include <QDebug>

TaperedBoxGeometry::TaperedBoxGeometry(QQuick3DObject *parent)
    : QQuick3DGeometry(parent)
{
    qDebug() << "TaperedBoxGeometry constructor";
    
    // Attack (pyramide inversée) + Cube (sustain) + Release (pyramide)
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    const float w = 50.0f;  // Demi-largeur
    const float h = 50.0f;  // Demi-hauteur du cube
    const float d = 50.0f;  // Demi-profondeur
    
    // Calcul des hauteurs de pyramides (compensées par le scale)
    const float cubeSize = 0.4f;
    const float scale = m_sustainHeight * cubeSize / 20.0f;
    const float hAttackPyramid = (scale > 0) ? (m_attackHeight / scale) : 20.0f;
    const float hReleasePyramid = (scale > 0) ? (m_releaseHeight / scale) : 20.0f;
    
    const float yAttackBottom = -h - hAttackPyramid; // Pointe de l'attaque (tout en bas)
    const float yBot = -h;                           // Base de l'attaque = Bas du cube
    const float yTop = h;                            // Haut du cube = Base du release
    const float yPeak = h + hReleasePyramid;         // Sommet du release
    
    // 18 vertices : 5 (attack) + 8 (cube) + 5 (release)
    Vertex vertices[] = {
        // === PYRAMIDE ATTACK (inversée, pointe en bas) - 5 vertices ===
        // Base de l'attack (= bas du cube, normales vers le bas)
        {-w, yBot,  d,  0.0f, -1.0f, 0.0f},  // 0: base-gauche-avant
        { w, yBot,  d,  0.0f, -1.0f, 0.0f},  // 1: base-droite-avant
        { w, yBot, -d,  0.0f, -1.0f, 0.0f},  // 2: base-droite-arrière
        {-w, yBot, -d,  0.0f, -1.0f, 0.0f},  // 3: base-gauche-arrière
        // Pointe de l'attack (en bas, centrée)
        {0.0f, yAttackBottom, 0.0f,  0.0f, -1.0f, 0.0f},  // 4: pointe
        
        // === CUBE (sustain) - 8 vertices ===
        // Face avant (Z+)
        {-w, yBot,  d,  0.0f, 0.0f, 1.0f},  // 5: bas-gauche-avant
        { w, yBot,  d,  0.0f, 0.0f, 1.0f},  // 6: bas-droite-avant
        { w, yTop,  d,  0.0f, 0.0f, 1.0f},  // 7: haut-droite-avant
        {-w, yTop,  d,  0.0f, 0.0f, 1.0f},  // 8: haut-gauche-avant
        // Face arrière (Z-)
        {-w, yBot, -d,  0.0f, 0.0f, -1.0f}, // 9: bas-gauche-arrière
        { w, yBot, -d,  0.0f, 0.0f, -1.0f}, // 10: bas-droite-arrière
        { w, yTop, -d,  0.0f, 0.0f, -1.0f}, // 11: haut-droite-arrière
        {-w, yTop, -d,  0.0f, 0.0f, -1.0f}, // 12: haut-gauche-arrière
        
        // === PYRAMIDE RELEASE (pointe en haut) - 5 vertices ===
        // Base du release (= haut du cube, normales vers le haut)
        {-w, yTop,  d,  0.0f, 1.0f, 0.0f},  // 13: base-gauche-avant
        { w, yTop,  d,  0.0f, 1.0f, 0.0f},  // 14: base-droite-avant
        { w, yTop, -d,  0.0f, 1.0f, 0.0f},  // 15: base-droite-arrière
        {-w, yTop, -d,  0.0f, 1.0f, 0.0f},  // 16: base-gauche-arrière
        // Sommet du release
        {0.0f, yPeak, 0.0f,  0.0f, 1.0f, 0.0f}  // 17: sommet
    };
    
    // Indices : 4 (attack) + 10 (cube sans faces haute/basse) + 4 (release) = 18 triangles
    quint32 indices[] = {
        // === ATTACK (pyramide inversée) - 4 faces ===
        0, 4, 1,   // Face avant
        1, 4, 2,   // Face droite
        2, 4, 3,   // Face arrière
        3, 4, 0,   // Face gauche
        
        // === CUBE (sustain) - 4 faces latérales ===
        5, 6, 7,   5, 7, 8,   // Face avant (Z+)
        10, 9, 12, 10, 12, 11, // Face arrière (Z-)
        9, 5, 8,   9, 8, 12,  // Face gauche (X-)
        6, 10, 11, 6, 11, 7,  // Face droite (X+)
        // Pas de face haute ni basse (remplacées par les pyramides)
        
        // === RELEASE (pyramide) - 4 faces ===
        13, 14, 17, // Face avant
        14, 15, 17, // Face droite
        15, 16, 17, // Face arrière
        16, 13, 17  // Face gauche
    };
    
    QByteArray vertexBuffer(reinterpret_cast<char*>(vertices), sizeof(vertices));
    QByteArray indexBuffer(reinterpret_cast<char*>(indices), sizeof(indices));
    
    qDebug() << "Setting up geometry - vertexBuffer:" << vertexBuffer.size() 
             << "indexBuffer:" << indexBuffer.size();
    
    setStride(sizeof(Vertex));
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    // Bounds : pyramide attack + cube + pyramide release
    setBounds(QVector3D(-w, yAttackBottom, -d), QVector3D(w, yPeak, d));
    
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

void TaperedBoxGeometry::setAttackHeight(float height)
{
    if (qFuzzyCompare(m_attackHeight, height))
        return;
    m_attackHeight = height;
    emit attackHeightChanged();
    updateGeometry();
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
    qDebug() << "updateGeometry() - attack:" << m_attackHeight << "sustain:" << m_sustainHeight << "release:" << m_releaseHeight;
    
    // Même logique que le constructeur
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    const float w = 50.0f;
    const float h = 50.0f;
    const float d = 50.0f;
    
    const float cubeSize = 0.4f;
    const float scale = m_sustainHeight * cubeSize / 20.0f;
    const float hAttackPyramid = (scale > 0) ? (m_attackHeight / scale) : 20.0f;
    const float hReleasePyramid = (scale > 0) ? (m_releaseHeight / scale) : 20.0f;
    
    const float yAttackBottom = -h - hAttackPyramid;
    const float yBot = -h;
    const float yTop = h;
    const float yPeak = h + hReleasePyramid;
    
    // 18 vertices
    Vertex vertices[] = {
        // ATTACK
        {-w, yBot,  d,  0.0f, -1.0f, 0.0f},
        { w, yBot,  d,  0.0f, -1.0f, 0.0f},
        { w, yBot, -d,  0.0f, -1.0f, 0.0f},
        {-w, yBot, -d,  0.0f, -1.0f, 0.0f},
        {0.0f, yAttackBottom, 0.0f,  0.0f, -1.0f, 0.0f},
        // CUBE
        {-w, yBot,  d,  0.0f, 0.0f, 1.0f},
        { w, yBot,  d,  0.0f, 0.0f, 1.0f},
        { w, yTop,  d,  0.0f, 0.0f, 1.0f},
        {-w, yTop,  d,  0.0f, 0.0f, 1.0f},
        {-w, yBot, -d,  0.0f, 0.0f, -1.0f},
        { w, yBot, -d,  0.0f, 0.0f, -1.0f},
        { w, yTop, -d,  0.0f, 0.0f, -1.0f},
        {-w, yTop, -d,  0.0f, 0.0f, -1.0f},
        // RELEASE
        {-w, yTop,  d,  0.0f, 1.0f, 0.0f},
        { w, yTop,  d,  0.0f, 1.0f, 0.0f},
        { w, yTop, -d,  0.0f, 1.0f, 0.0f},
        {-w, yTop, -d,  0.0f, 1.0f, 0.0f},
        {0.0f, yPeak, 0.0f,  0.0f, 1.0f, 0.0f}
    };
    
    quint32 indices[] = {
        0, 4, 1,   1, 4, 2,   2, 4, 3,   3, 4, 0,
        5, 6, 7,   5, 7, 8,
        10, 9, 12, 10, 12, 11,
        9, 5, 8,   9, 8, 12,
        6, 10, 11, 6, 11, 7,
        13, 14, 17, 14, 15, 17, 15, 16, 17, 16, 13, 17
    };
    
    m_vertexBuffer = QByteArray(reinterpret_cast<char*>(vertices), sizeof(vertices));
    m_indexBuffer = QByteArray(reinterpret_cast<char*>(indices), sizeof(indices));
    
    setVertexData(m_vertexBuffer);
    setIndexData(m_indexBuffer);
    setBounds(QVector3D(-w, yAttackBottom, -d), QVector3D(w, yPeak, d));
    
    update();
}
