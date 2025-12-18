const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { User } = require('../models');
const { auth } = require('../middleware/auth');

// ارسال کد تایید
router.post('/send-code', async (req, res) => {
  try {
    let { phone } = req.body;
    // تبدیل اعداد فارسی به انگلیسی
    phone = convertPersianToEnglish(phone || '');
    
    if (!phone || phone.length !== 11) {
      return res.status(400).json({ success: false, message: 'شماره موبایل نامعتبر است' });
    }

    let user = await User.findOne({ where: { phone } });
    if (!user) {
      user = await User.create({ phone });
    }

    // کد پیش‌فرض 1234 (چون پنل پیامکی نداریم)
    const code = '1234';
    user.verificationCode = code;
    user.verificationExpires = new Date(Date.now() + 5 * 60 * 1000);
    await user.save();

    res.json({ success: true, message: 'کد تایید ارسال شد (کد پیش‌فرض: 1234)' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// تبدیل اعداد فارسی به انگلیسی
function convertPersianToEnglish(str) {
  const persianNumbers = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  let result = str;
  for (let i = 0; i < 10; i++) {
    result = result.replace(new RegExp(persianNumbers[i], 'g'), i.toString());
    result = result.replace(new RegExp(arabicNumbers[i], 'g'), i.toString());
  }
  return result;
}

// تایید کد و ورود
router.post('/verify', async (req, res) => {
  try {
    let { phone, code } = req.body;
    
    // تبدیل اعداد فارسی به انگلیسی
    phone = convertPersianToEnglish(phone || '');
    code = convertPersianToEnglish(code || '');

    const user = await User.findOne({ where: { phone } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'کاربر یافت نشد' });
    }

    // کد پیش‌فرض 1234 همیشه قبول میشه
    if (code !== '1234' && user.verificationCode !== code) {
      return res.status(400).json({ success: false, message: 'کد تایید نامعتبر است' });
    }

    user.verificationCode = null;
    user.verificationExpires = null;
    user.isVerified = true;
    await user.save();

    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      success: true,
      message: 'ورود موفق',
      token,
      user: { id: user.id, phone: user.phone, name: user.name, role: user.role, profileImage: user.profileImage }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت اطلاعات کاربر
router.get('/me', auth, async (req, res) => {
  res.json({ success: true, user: req.user });
});

// به‌روزرسانی پروفایل
router.put('/profile', auth, async (req, res) => {
  try {
    const { 
      name, profileImage, bio, city, province, 
      birthDate, skills, experience, education,
      instagram, telegram, website 
    } = req.body;
    console.log('📝 Update profile:', { userId: req.userId, name });
    
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (profileImage !== undefined) updateData.profileImage = profileImage;
    if (bio !== undefined) updateData.bio = bio;
    if (city !== undefined) updateData.city = city;
    if (province !== undefined) updateData.province = province;
    if (birthDate !== undefined) updateData.birthDate = birthDate;
    if (skills !== undefined) updateData.skills = skills;
    if (experience !== undefined) updateData.experience = experience;
    if (education !== undefined) updateData.education = education;
    if (instagram !== undefined) updateData.instagram = instagram;
    if (telegram !== undefined) updateData.telegram = telegram;
    if (website !== undefined) updateData.website = website;
    
    await User.update(updateData, { where: { id: req.userId } });
    const user = await User.findByPk(req.userId, { attributes: { exclude: ['password', 'verificationCode'] } });
    console.log('✅ Updated user:', user?.toJSON());
    res.json({ success: true, user });
  } catch (error) {
    console.error('❌ Profile update error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ورود ادمین
router.post('/admin-login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    const user = await User.findOne({ where: { phone, role: 'admin' } });
    if (!user) {
      return res.status(401).json({ success: false, message: 'کاربر ادمین یافت نشد' });
    }

    const validPassword = password === (process.env.ADMIN_PASSWORD || '123456');
    if (!validPassword) {
      return res.status(401).json({ success: false, message: 'رمز عبور اشتباه است' });
    }

    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: '24h' }
    );

    res.json({ success: true, token, user: { id: user.id, phone: user.phone, name: user.name, role: user.role } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ایجاد ادمین اولیه
router.post('/create-admin', async (req, res) => {
  try {
    const adminExists = await User.findOne({ where: { role: 'admin' } });
    if (adminExists) {
      return res.status(400).json({ success: false, message: 'ادمین قبلاً ایجاد شده' });
    }

    const { phone, name } = req.body;
    const admin = await User.create({ phone, name, role: 'admin', isActive: true, isVerified: true });

    res.json({ success: true, message: 'ادمین ایجاد شد', user: { phone: admin.phone, name: admin.name } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
