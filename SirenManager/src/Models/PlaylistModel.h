#ifndef PLAYLISTMODEL_H
#define PLAYLISTMODEL_H

#include <QAbstractListModel>
#include <QString>

struct PlaylistEntry {
    int slot;
    QString filename;
    QString pseudo;
    bool boucle;
    bool enchain;
};

class PlaylistModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        SlotRole = Qt::UserRole + 1,
        FilenameRole,
        PseudoRole,
        BoucleRole,
        EnchainRole
    };

    explicit PlaylistModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role = Qt::EditRole) override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addEntry(const PlaylistEntry &entry);
    Q_INVOKABLE void removeEntry(int index);
    Q_INVOKABLE void clear();

private:
    QList<PlaylistEntry> m_entries;
};

#endif // PLAYLISTMODEL_H


