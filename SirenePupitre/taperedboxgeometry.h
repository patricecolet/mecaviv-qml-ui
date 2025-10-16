#ifndef TAPEREDBOXGEOMETRY_H
#define TAPEREDBOXGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVector3D>

// Géométrie custom : cube (sustain) + pyramide effilée (release)
class TaperedBoxGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(TaperedBoxGeometry)
    
    Q_PROPERTY(float attackTime READ attackTime WRITE setAttackTime NOTIFY attackTimeChanged)
    Q_PROPERTY(float duration READ duration WRITE setDuration NOTIFY durationChanged)
    Q_PROPERTY(float totalHeight READ totalHeight WRITE setTotalHeight NOTIFY totalHeightChanged)
    Q_PROPERTY(float releaseHeight READ releaseHeight WRITE setReleaseHeight NOTIFY releaseHeightChanged)
    Q_PROPERTY(float velocity READ velocity WRITE setVelocity NOTIFY velocityChanged)
    Q_PROPERTY(float baseSize READ baseSize WRITE setBaseSize NOTIFY baseSizeChanged)
    Q_PROPERTY(int releaseSegments READ releaseSegments WRITE setReleaseSegments NOTIFY releaseSegmentsChanged)

public:
    explicit TaperedBoxGeometry(QQuick3DObject *parent = nullptr);
    
    float attackTime() const { return m_attackTime; }
    void setAttackTime(float time);
    
    float duration() const { return m_duration; }
    void setDuration(float dur);
    
    float totalHeight() const { return m_totalHeight; }
    void setTotalHeight(float height);
    
    float releaseHeight() const { return m_releaseHeight; }
    void setReleaseHeight(float height);
    
    float velocity() const { return m_velocity; }
    void setVelocity(float vel);
    
    float baseSize() const { return m_baseSize; }
    void setBaseSize(float size);
    
    int releaseSegments() const { return m_releaseSegments; }
    void setReleaseSegments(int segments);

signals:
    void attackTimeChanged();
    void durationChanged();
    void totalHeightChanged();
    void releaseHeightChanged();
    void velocityChanged();
    void baseSizeChanged();
    void releaseSegmentsChanged();

private:
    void updateGeometry();
    
    float m_attackTime = 0.0f;
    float m_duration = 1000.0f;
    float m_totalHeight = 1.0f;
    float m_releaseHeight = 0.3f;
    float m_velocity = 127.0f;
    float m_baseSize = 20.0f;
    int m_releaseSegments = 4;
    
    // Garder les buffers en membres pour qu'ils persistent
    QByteArray m_vertexBuffer;
    QByteArray m_indexBuffer;
};

#endif // TAPEREDBOXGEOMETRY_H

