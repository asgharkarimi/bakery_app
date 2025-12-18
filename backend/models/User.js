const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const bcrypt = require('bcryptjs');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  phone: {
    type: DataTypes.STRING(11),
    allowNull: false,
    unique: true
  },
  password: {
    type: DataTypes.STRING
  },
  name: {
    type: DataTypes.STRING
  },
  role: {
    type: DataTypes.ENUM('user', 'admin'),
    defaultValue: 'user'
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    field: 'is_active'
  },
  isVerified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_verified'
  },
  profileImage: {
    type: DataTypes.STRING,
    field: 'profile_image'
  },
  verificationCode: {
    type: DataTypes.STRING(6),
    field: 'verification_code'
  },
  verificationExpires: {
    type: DataTypes.DATE,
    field: 'verification_expires'
  },
  lastSeen: {
    type: DataTypes.DATE,
    field: 'last_seen'
  },
  isOnline: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    field: 'is_online'
  },
  // فیلدهای پروفایل کامل
  bio: {
    type: DataTypes.TEXT
  },
  city: {
    type: DataTypes.STRING
  },
  province: {
    type: DataTypes.STRING
  },
  birthDate: {
    type: DataTypes.DATEONLY,
    field: 'birth_date'
  },
  skills: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  experience: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    comment: 'سال‌های سابقه کار'
  },
  education: {
    type: DataTypes.STRING
  },
  instagram: {
    type: DataTypes.STRING
  },
  telegram: {
    type: DataTypes.STRING
  },
  website: {
    type: DataTypes.STRING
  }
}, {
  tableName: 'users',
  hooks: {
    beforeSave: async (user) => {
      if (user.changed('password') && user.password) {
        user.password = await bcrypt.hash(user.password, 10);
      }
    }
  }
});

User.prototype.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

module.exports = User;
