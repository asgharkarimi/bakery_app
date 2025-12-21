const express = require('express');
const router = express.Router();
const { Op } = require('sequelize');
const { BakeryAd, User } = require('../models');
const { auth } = require('../middleware/auth');

// آگهی‌های من - باید قبل از /:id باشه
router.get('/my/list', auth, async (req, res) => {
  try {
    const ads = await BakeryAd.findAll({ where: { userId: req.userId }, order: [['createdAt', 'DESC']] });
    res.json({ success: true, data: ads });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// تست - همه آگهی‌ها بدون فیلتر
router.get('/debug/all', async (req, res) => {
  try {
    const ads = await BakeryAd.findAll();
    console.log('📋 All bakery ads:', ads.map(a => ({ id: a.id, title: a.title, isActive: a.isActive, isApproved: a.isApproved })));
    res.json({ success: true, data: ads, count: ads.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت همه آگهی‌ها
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 20, type, location, search, province, minPrice, maxPrice, minFlourQuota, maxFlourQuota } = req.query;
    const where = { isActive: true, isApproved: true };

    console.log('📋 Fetching bakery ads with where:', where);

    if (type) where.type = type;
    if (location) where.location = { [Op.like]: `%${location}%` };
    if (search) where.title = { [Op.like]: `%${search}%` };
    if (province) where.location = { [Op.like]: `%${province}%` };
    
    // فیلتر قیمت
    if (minPrice || maxPrice) {
      where.salePrice = {};
      if (minPrice) where.salePrice[Op.gte] = Number(minPrice);
      if (maxPrice) where.salePrice[Op.lte] = Number(maxPrice);
    }
    
    // فیلتر سهمیه آرد
    if (minFlourQuota || maxFlourQuota) {
      where.flourQuota = {};
      if (minFlourQuota) where.flourQuota[Op.gte] = Number(minFlourQuota);
      if (maxFlourQuota) where.flourQuota[Op.lte] = Number(maxFlourQuota);
    }

    const { count, rows } = await BakeryAd.findAndCountAll({
      where,
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'phone'] }],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    console.log('📋 Found', count, 'bakery ads');

    res.json({ success: true, data: rows, total: count, page: Number(page), pages: Math.ceil(count / limit) });
  } catch (error) {
    console.error('❌ Error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت یک آگهی
router.get('/:id', async (req, res) => {
  try {
    const ad = await BakeryAd.findByPk(req.params.id, {
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
    console.log('📝 Creating bakery ad with data:', req.body);
    console.log('📸 Images received:', req.body.images);
    
    // چک کردن اینکه کاربر ادمین هست یا نه
    const user = await User.findByPk(req.userId);
    const isAdmin = user && (user.role === 'admin' || user.phone === '09199541276');
    
    const ad = await BakeryAd.create({ 
      ...req.body, 
      userId: req.userId,
      isApproved: isAdmin
    });
    console.log('✅ Created bakery ad:', ad.id, 'images:', ad.images, 'auto-approved:', isAdmin);
    res.status(201).json({ success: true, data: ad });
  } catch (error) {
    console.error('❌ Error creating bakery ad:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ویرایش آگهی
router.put('/:id', auth, async (req, res) => {
  try {
    const ad = await BakeryAd.findOne({ where: { id: req.params.id, userId: req.userId } });
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
    const deleted = await BakeryAd.destroy({ where: { id: req.params.id, userId: req.userId } });
    if (!deleted) return res.status(404).json({ success: false, message: 'آگهی یافت نشد' });
    res.json({ success: true, message: 'آگهی حذف شد' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
