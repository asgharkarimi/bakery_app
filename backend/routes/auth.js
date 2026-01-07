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
    
    if (!phone || phone.length !== 11 || !phone.startsWith('09')) {
      return res.status(400).json({ success: false, message: 'شماره موبایل نامعتبر است' });
    }

    let user = await User.findOne({ where: { phone } });
    if (!user) {
      user = await User.create({ phone });
    }

    // کد تست: همیشه 1234
    const code = '1234';
    user.verificationCode = code;
    user.verificationExpires = new Date(Date.now() + 5 * 60 * 1000);
    user.verificationAttempts = 0; // ریست تعداد تلاش‌ها
    await user.save();

    // TODO: ارسال SMS واقعی
    // در محیط توسعه کد رو لاگ میکنیم
    if (process.env.NODE_ENV === 'development') {
      console.log(`📱 کد تایید برای ${phone}: ${code}`);
    }

    res.json({ 
      success: true, 
      message: 'کد تایید ارسال شد',
      // فقط در محیط توسعه کد رو برگردون
      ...(process.env.NODE_ENV === 'development' && { devCode: code })
    });
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

    // چک کردن تعداد تلاش‌های ناموفق
    if (user.verificationAttempts >= 5) {
      // چک کردن زمان آخرین تلاش - اگه 2 دقیقه گذشته باشه ریست کن
      const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
      if (user.updatedAt && new Date(user.updatedAt) < twoMinutesAgo) {
        // 2 دقیقه گذشته، ریست تعداد تلاش‌ها
        user.verificationAttempts = 0;
        await user.save();
      } else {
        // هنوز 2 دقیقه نگذشته
        const remainingSeconds = Math.ceil((new Date(user.updatedAt).getTime() + 2 * 60 * 1000 - Date.now()) / 1000);
        return res.status(429).json({ 
          success: false, 
          message: `تعداد تلاش‌ها بیش از حد مجاز است. ${remainingSeconds} ثانیه صبر کنید.`,
          remainingSeconds 
        });
      }
    }

    // چک کردن انقضای کد
    if (user.verificationExpires && new Date() > user.verificationExpires) {
      return res.status(400).json({ success: false, message: 'کد تایید منقضی شده است' });
    }

    // چک کردن کد
    if (user.verificationCode !== code) {
      // افزایش تعداد تلاش‌های ناموفق
      await user.increment('verificationAttempts');
      return res.status(400).json({ success: false, message: 'کد تایید نامعتبر است' });
    }

    user.verificationCode = null;
    user.verificationExpires = null;
    user.verificationAttempts = 0;
    user.isVerified = true;
    await user.save();

    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET,
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
