const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Chat = sequelize.define('Chat', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  senderId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    field: 'sender_id',
    references: { model: 'users', key: 'id' }
  },
  receiverId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    field: 'receiver_id',
    references: { model: 'users', key: 'id' }
  },
  message: {
    type: DataTypes.TEXT
  },
  messageType: {
    type: DataTypes.ENUM('text', 'image', 'video', 'voice'),
    defaultValue: 'text',
    field: 'message_type'
  },
  mediaUrl: {
    type: DataTypes.STRING,
    field: 'media_url'
  },
  replyToId: {
    type: DataTypes.INTEGER,
    field: 'reply_to_id',
    references: { model: 'chats', key: 'id' }
  },
  isDelivered: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_delivered'
  },
  isRead: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_read'
  },
  isEncrypted: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_encrypted'
  },
  isEdited: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_edited'
  },
  isDeleted: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_deleted'
  }
}, {
  tableName: 'chats',
  indexes: [
    { fields: ['sender_id', 'receiver_id'] }
  ]
});

module.exports = Chat;
