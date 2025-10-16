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
    
    // === CALCULS MUSICAUX ADSR ===
    // 1. Ratio de la durée utilisée par l'attack (pour la HAUTEUR)
    const float attackRatio = (m_attackTime > 0.0f && m_duration > 0.0f) 
        ? qMin(1.0f, m_attackTime / m_duration)  // Proportion de durée pour l'attack
        : 0.0f;  // Pas d'attack si attackTime = 0
    
    // 2. Ratio d'attack complété (pour la VÉLOCITÉ)
    const float velocityRatio = (m_attackTime > 0.0f && m_duration > 0.0f)
        ? qMin(1.0f, m_duration / m_attackTime)  // Portion d'attack complétée
        : 1.0f;  // Vélocité immédiate si pas d'attack
    
    // 3. Vélocité effective atteinte
    const float effectiveVelocity = m_velocity * velocityRatio;
    const float velocityFactor = (effectiveVelocity / 127.0f * 0.8f + 0.2f);  // 0.2 à 1.0
    
    // 4. Dimensions basées sur effectiveVelocity
    const float w = velocityFactor * m_baseSize / 2.0f;  // Demi-largeur
    const float d = m_baseSize / 2.0f;  // Demi-profondeur
    
    // 5. Hauteurs visuelles pour attack et sustain
    // attackHeight visuelle = portion de totalHeight utilisée pour l'attack
    const float attackHeightVisual = m_totalHeight * attackRatio;
    const float sustainHeight = m_totalHeight - attackHeightVisual;
    
    // 6. Hauteurs des pyramides
    const float hAttackPyramid = attackHeightVisual;
    const float hReleasePyramid = m_releaseHeight;
    
    // 7. Coordonnées Y - CENTRE SUR TOTALHEIGHT (attack+sustain constant)
    // Le centre des bounds pour totalHeight est à Y=0 (ne bouge pas avec attack)
    const float halfTotal = m_totalHeight / 2.0f;
    const float yAttackBottom = -halfTotal;                    // Bas (pointe attack)
    const float yBot = -halfTotal + hAttackPyramid;            // Fin attack = début sustain
    const float yTop = halfTotal;                              // Haut sustain
    const float yPeak = halfTotal + hReleasePyramid;           // Sommet release
    
    qDebug() << "Constructor - attackTime:" << m_attackTime << "duration:" << m_duration 
             << "attackRatio:" << attackRatio << "effectiveVelocity:" << effectiveVelocity
             << "attackHeightVisual:" << attackHeightVisual << "sustainHeight:" << sustainHeight;
    
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

void TaperedBoxGeometry::setAttackTime(float time)
{
    if (qFuzzyCompare(m_attackTime, time))
        return;
    m_attackTime = time;
    emit attackTimeChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setDuration(float dur)
{
    if (qFuzzyCompare(m_duration, dur))
        return;
    m_duration = dur;
    emit durationChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setTotalHeight(float height)
{
    if (qFuzzyCompare(m_totalHeight, height))
        return;
    m_totalHeight = height;
    emit totalHeightChanged();
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

void TaperedBoxGeometry::setVelocity(float vel)
{
    if (qFuzzyCompare(m_velocity, vel))
        return;
    m_velocity = vel;
    emit velocityChanged();
    updateGeometry();
}

void TaperedBoxGeometry::setBaseSize(float size)
{
    if (qFuzzyCompare(m_baseSize, size))
        return;
    m_baseSize = size;
    emit baseSizeChanged();
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

void TaperedBoxGeometry::updateGeometry()
{
    // Même logique que le constructeur
    struct Vertex {
        float x, y, z;
        float nx, ny, nz;
    };
    
    // === CALCULS MUSICAUX ADSR ===
    // 1. Ratio de la durée utilisée par l'attack (pour la HAUTEUR)
    const float attackRatio = (m_attackTime > 0.0f && m_duration > 0.0f) 
        ? qMin(1.0f, m_attackTime / m_duration)  // Proportion de durée pour l'attack
        : 0.0f;  // Pas d'attack si attackTime = 0
    
    // 2. Ratio d'attack complété (pour la VÉLOCITÉ)
    const float velocityRatio = (m_attackTime > 0.0f && m_duration > 0.0f)
        ? qMin(1.0f, m_duration / m_attackTime)  // Portion d'attack complétée
        : 1.0f;  // Vélocité immédiate si pas d'attack
    
    // 3. Vélocité effective atteinte
    const float effectiveVelocity = m_velocity * velocityRatio;
    const float velocityFactor = (effectiveVelocity / 127.0f * 0.8f + 0.2f);  // 0.2 à 1.0
    
    // 4. Dimensions basées sur effectiveVelocity
    const float w = velocityFactor * m_baseSize / 2.0f;  // Demi-largeur
    const float d = m_baseSize / 2.0f;  // Demi-profondeur
    
    // 5. Hauteurs visuelles pour attack et sustain
    // attackHeight visuelle = portion de totalHeight utilisée pour l'attack
    const float attackHeightVisual = m_totalHeight * attackRatio;
    const float sustainHeight = m_totalHeight - attackHeightVisual;
    
    // 6. Hauteurs des pyramides
    const float hAttackPyramid = attackHeightVisual;
    const float hReleasePyramid = m_releaseHeight;
    
    // 7. Coordonnées Y - CENTRE SUR TOTALHEIGHT (attack+sustain constant)
    // Le centre des bounds pour totalHeight est à Y=0 (ne bouge pas avec attack)
    const float halfTotal = m_totalHeight / 2.0f;
    const float yAttackBottom = -halfTotal;                    // Bas (pointe attack)
    const float yBot = -halfTotal + hAttackPyramid;            // Fin attack = début sustain
    const float yTop = halfTotal;                              // Haut sustain
    const float yPeak = halfTotal + hReleasePyramid;           // Sommet release
    
    qDebug() << "updateGeometry() - attackTime:" << m_attackTime << "duration:" << m_duration 
             << "attackRatio:" << attackRatio << "effectiveVelocity:" << effectiveVelocity
             << "attackHeightVisual:" << attackHeightVisual << "sustainHeight:" << sustainHeight
             << "releaseHeight:" << m_releaseHeight << "width:" << (w*2) << "depth:" << (d*2)
             << "bounds: yAttackBottom=" << yAttackBottom << "yPeak=" << yPeak;
    
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
