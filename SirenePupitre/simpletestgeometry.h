#ifndef SIMPLETESTGEOMETRY_H
#define SIMPLETESTGEOMETRY_H

#include <QQuick3DGeometry>

// Test minimal : juste un triangle pour vérifier que ça fonctionne
class SimpleTestGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(SimpleTestGeometry)

public:
    SimpleTestGeometry();
};

#endif

