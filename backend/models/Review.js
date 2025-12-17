const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Review = sequelize.define('Review', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  userId: {
    type: DataTypes.INTEGER,
    field: 'user_id',
    references: { model: 'users', key: 'id' }
  },
  targetType: {
    type: DataTypes.ENUM('job_ad', 'bakery_ad', 'equipment_ad', 'user'),
    allowNull: false,
    field: 'target_type'
  },
  targetId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    field: 'target_id'
  },
  rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  comment: {
    type: DataTypes.TEXT
  },
  tags: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  isApproved: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_approved'
  }
}, {
  tableName: 'reviews',
  indexes: [
    { fields: ['target_type', 'target_id'] }
  ]
});

module.exports = Review;
