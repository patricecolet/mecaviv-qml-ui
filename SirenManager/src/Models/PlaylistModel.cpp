#include "PlaylistModel.h"

PlaylistModel::PlaylistModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PlaylistModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_entries.size();
}

QVariant PlaylistModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size()) {
        return QVariant();
    }

    const PlaylistEntry &entry = m_entries[index.row()];

    switch (role) {
        case SlotRole:
            return entry.slot;
        case FilenameRole:
            return entry.filename;
        case PseudoRole:
            return entry.pseudo;
        case BoucleRole:
            return entry.boucle;
        case EnchainRole:
            return entry.enchain;
        default:
            return QVariant();
    }
}

bool PlaylistModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || index.row() >= m_entries.size()) {
        return false;
    }

    PlaylistEntry &entry = m_entries[index.row()];

    switch (role) {
        case FilenameRole:
            entry.filename = value.toString();
            break;
        case PseudoRole:
            entry.pseudo = value.toString();
            break;
        case BoucleRole:
            entry.boucle = value.toBool();
            break;
        case EnchainRole:
            entry.enchain = value.toBool();
            break;
        default:
            return false;
    }

    emit dataChanged(index, index, {role});
    return true;
}

QHash<int, QByteArray> PlaylistModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[SlotRole] = "slot";
    roles[FilenameRole] = "filename";
    roles[PseudoRole] = "pseudo";
    roles[BoucleRole] = "boucle";
    roles[EnchainRole] = "enchain";
    return roles;
}

void PlaylistModel::addEntry(const PlaylistEntry &entry)
{
    beginInsertRows(QModelIndex(), m_entries.size(), m_entries.size());
    m_entries.append(entry);
    endInsertRows();
}

void PlaylistModel::removeEntry(int index)
{
    if (index < 0 || index >= m_entries.size()) {
        return;
    }

    beginRemoveRows(QModelIndex(), index, index);
    m_entries.removeAt(index);
    endRemoveRows();
}

void PlaylistModel::clear()
{
    beginResetModel();
    m_entries.clear();
    endResetModel();
}


