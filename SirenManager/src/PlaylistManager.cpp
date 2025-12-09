#include "PlaylistManager.h"
#include <QRegularExpression>

PlaylistManager::PlaylistManager(QObject *parent)
    : QObject(parent)
{
}

QStringList PlaylistManager::parsePlaylistContent(const QString &content)
{
    QStringList entries;
    // TODO: Implement playlist parsing
    return entries;
}

QString PlaylistManager::formatPlaylistEntry(int slot, const QString &filename, 
                                              const QString &pseudo, bool boucle, bool enchain)
{
    return QStringLiteral("{ [n=%1] [s=%2] [a=%3] [B=%4] [E=%5] }")
        .arg(slot)
        .arg(filename)
        .arg(pseudo)
        .arg(boucle ? 1 : 0)
        .arg(enchain ? 1 : 0);
}


