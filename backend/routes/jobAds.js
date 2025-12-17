const express = require('express');
const router = express.Router();
const { Op } = require('sequelize');
const { JobAd, User } = require('../models');
const { auth } = require('../middleware/auth');

// آگهی‌های من - باید قبل از /:id باشه
router.get('/my/list', auth, async (req, res) => {
  try {
    const ads = await JobAd.findAll({ where: { userId: req.userId }, order: [['createdAt', 'DESC']] });
    res.json({ success: true, data: ads });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت همه آگهی‌ها
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 20, category, location, minSalary, maxSalary, search } = req.query;
    // فقط آگهی‌های فعال و تایید شده توسط ادمین نمایش داده میشن
    const where = { isActive: true, isApproved: true };

    if (category) where.category = category;
    if (location) where.location = { [Op.like]: `%${location}%` };
    if (minSalary) where.salary = { ...where.salary, [Op.gte]: minSalary };
    if (maxSalary) where.salary = { ...where.salary, [Op.lte]: maxSalary };
    if (search) where.title = { [Op.like]: `%${search}%` };

    const { count, rows } = await JobAd.findAndCountAll({
      where,
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'phone'] }],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    res.json({ success: true, data: rows, total: count, page: Number(page), pages: Math.ceil(count / limit) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت یک آگهی
router.get('/:id', async (req, res) => {
  try {
    const ad = await JobAd.findByPk(req.params.id, {
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'phone'] }]
    });
    if (!ad) return res.status(404).json({ success: false, message: 'آگهی یافت نشد' });

    ad.views += 1;
    await ad.save();

    res.json({ success: true, data: ad });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ایجاد آگهی
router.post('/', auth, async (req, res) => {
  try {
    console.log('📝 ایجاد آگهی:', req.body);
    console.log('👤 کاربر:', req.userId);
    const ad = await JobAd.create({ ...req.body, userId: req.userId });
    console.log('✅ آگهی ایجاد شد:', ad.id);
    res.status(201).json({ success: true, data: ad });
  } catch (error) {
    console.error('❌ خطا در ایجاد آگهی:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ویرایش آگهی
router.put('/:id', auth, async (req, res) => {
  try {
    const ad = await JobAd.findOne({ where: { id: req.params.id, userId: req.userId } });
    if (!ad) return res.status(404).json({ success: false, message: 'آگهی یافت نشد' });

    await ad.update(req.body);
    res.json({ success: true, data: ad });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// حذف آگهی
router.delete('/:id', auth, async (req, res) => {
  try {
    const deleted = await JobAd.destroy({ where: { id: req.params.id, userId: req.userId } });
    if (!deleted) return res.status(404).json({ success: false, message: 'آگهی یافت نشد' });
    res.json({ success: true, message: 'آگهی حذف شد' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
