const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const JobAd = sequelize.define('JobAd', {
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
  title: {
    type: DataTypes.STRING,
    allowNull: false
  },
  category: {
    type: DataTypes.STRING,
    allowNull: false
  },
  dailyBags: {
    type: DataTypes.INTEGER,
    field: 'daily_bags'
  },
  salary: {
    type: DataTypes.BIGINT,
    allowNull: false
  },
  location: {
    type: DataTypes.STRING,
    allowNull: false
  },
  province: {
    type: DataTypes.STRING
  },
  phoneNumber: {
    type: DataTypes.STRING(11),
    allowNull: false,
    field: 'phone_number'
  },
  description: {
    type: DataTypes.TEXT
  },
  hasInsurance: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'has_insurance'
  },
  hasAccommodation: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'has_accommodation'
  },
  hasVacation: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'has_vacation'
  },
  vacationDays: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    field: 'vacation_days'
  },
  images: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    field: 'is_active'
  },
  isApproved: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_approved'
  },
  views: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'job_ads',
  indexes: [
    { fields: ['category'] },
    { fields: ['location'] },
    { fields: ['is_active', 'is_approved'] }
  ]
});

module.exports = JobAd;
