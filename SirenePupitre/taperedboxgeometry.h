#ifndef TAPEREDBOXGEOMETRY_H
#define TAPEREDBOXGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVector3D>

// Géométrie custom : cube (sustain) + pyramide effilée (release)
class TaperedBoxGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(TaperedBoxGeometry)
    
    Q_PROPERTY(float attackHeight READ attackHeight WRITE setAttackHeight NOTIFY attackHeightChanged)
    Q_PROPERTY(float sustainHeight READ sustainHeight WRITE setSustainHeight NOTIFY sustainHeightChanged)
    Q_PROPERTY(float releaseHeight READ releaseHeight WRITE setReleaseHeight NOTIFY releaseHeightChanged)
    Q_PROPERTY(int releaseSegments READ releaseSegments WRITE setReleaseSegments NOTIFY releaseSegmentsChanged)
    Q_PROPERTY(float width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(float depth READ depth WRITE setDepth NOTIFY depthChanged)

public:
    explicit TaperedBoxGeometry(QQuick3DObject *parent = nullptr);
    
    float attackHeight() const { return m_attackHeight; }
    void setAttackHeight(float height);
    
    float sustainHeight() const { return m_sustainHeight; }
    void setSustainHeight(float height);
    
    float releaseHeight() const { return m_releaseHeight; }
    void setReleaseHeight(float height);
    
    int releaseSegments() const { return m_releaseSegments; }
    void setReleaseSegments(int segments);
    
    float width() const { return m_width; }
    void setWidth(float w);
    
    float depth() const { return m_depth; }
    void setDepth(float d);

signals:
    void attackHeightChanged();
    void sustainHeightChanged();
    void releaseHeightChanged();
    void releaseSegmentsChanged();
    void widthChanged();
    void depthChanged();

private:
    void updateGeometry();
    
    float m_attackHeight = 0.1f;
    float m_sustainHeight = 1.0f;
    float m_releaseHeight = 0.3f;
    int m_releaseSegments = 4;
    float m_width = 1.0f;
    float m_depth = 1.0f;
    
    // Garder les buffers en membres pour qu'ils persistent
    QByteArray m_vertexBuffer;
    QByteArray m_indexBuffer;
};

#endif // TAPEREDBOXGEOMETRY_H

