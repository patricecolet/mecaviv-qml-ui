#ifndef PLAYLISTMANAGER_H
#define PLAYLISTMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include "Config/MachineType.h"

class PlaylistManager : public QObject
{
    Q_OBJECT

public:
    explicit PlaylistManager(QObject *parent = nullptr);
    
    // Parse playlist format: {[n=X][s=filename][a=pseudo][B=0/1][E=0/1]}
    Q_INVOKABLE QStringList parsePlaylistContent(const QString &content);
    Q_INVOKABLE QString formatPlaylistEntry(int slot, const QString &filename, 
                                            const QString &pseudo, bool boucle, bool enchain);
};

#endif // PLAYLISTMANAGER_H


