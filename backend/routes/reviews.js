const express = require('express');
const router = express.Router();
const { Review, User } = require('../models');
const { auth } = require('../middleware/auth');

// دریافت نظرات یک آگهی
router.get('/:targetType/:targetId', async (req, res) => {
  try {
    const { targetType, targetId } = req.params;
    const { page = 1, limit = 20 } = req.query;

    const { count, rows } = await Review.findAndCountAll({
      where: { targetType, targetId, isApproved: true },
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'profileImage'] }],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    res.json({ success: true, data: rows, total: count });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ثبت نظر
router.post('/', auth, async (req, res) => {
  try {
    const { targetType, targetId, rating, comment, tags } = req.body;

    const review = await Review.create({
      userId: req.userId,
      targetType,
      targetId,
      rating,
      comment,
      tags: tags || []
    });

    res.status(201).json({ success: true, data: review });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت نظرات کاربر فعلی
router.get('/my/list', auth, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const { count, rows } = await Review.findAndCountAll({
      where: { userId: req.userId },
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    res.json({ success: true, data: rows, total: count });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ویرایش نظر
router.put('/:id', auth, async (req, res) => {
  try {
    const review = await Review.findOne({ where: { id: req.params.id, userId: req.userId } });
    if (!review) return res.status(404).json({ success: false, message: 'نظر یافت نشد' });

    const { rating, comment, tags } = req.body;
    await review.update({ 
      rating, 
      comment, 
      tags: tags || [],
      isApproved: false // بعد از ویرایش نیاز به تایید مجدد
    });

    res.json({ success: true, data: review, message: 'نظر ویرایش شد و پس از تایید نمایش داده می‌شود' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// حذف نظر
router.delete('/:id', auth, async (req, res) => {
  try {
    const deleted = await Review.destroy({ where: { id: req.params.id, userId: req.userId } });
    if (!deleted) return res.status(404).json({ success: false, message: 'نظر یافت نشد' });
    res.json({ success: true, message: 'نظر حذف شد' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== روت‌های ادمین =====

// دریافت همه نظرات در انتظار تایید (ادمین)
router.get('/admin/pending', auth, async (req, res) => {
  try {
    const user = await User.findByPk(req.userId);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'دسترسی غیرمجاز' });
    }

    const { page = 1, limit = 20 } = req.query;
    const { count, rows } = await Review.findAndCountAll({
      where: { isApproved: false },
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'profileImage'] }],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    res.json({ success: true, data: rows, total: count });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت همه نظرات (ادمین)
router.get('/admin/all', auth, async (req, res) => {
  try {
    const user = await User.findByPk(req.userId);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'دسترسی غیرمجاز' });
    }

    const { page = 1, limit = 20, status } = req.query;
    const where = {};
    if (status === 'approved') where.isApproved = true;
    if (status === 'pending') where.isApproved = false;

    const { count, rows } = await Review.findAndCountAll({
      where,
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'profileImage'] }],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    res.json({ success: true, data: rows, total: count });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// تایید نظر (ادمین)
router.put('/admin/:id/approve', auth, async (req, res) => {
  try {
    const user = await User.findByPk(req.userId);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'دسترسی غیرمجاز' });
    }

    const review = await Review.findByPk(req.params.id);
    if (!review) {
      return res.status(404).json({ success: false, message: 'نظر یافت نشد' });
    }

    review.isApproved = true;
    await review.save();

    res.json({ success: true, message: 'نظر تایید شد', data: review });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// رد نظر (ادمین)
router.put('/admin/:id/reject', auth, async (req, res) => {
  try {
    const user = await User.findByPk(req.userId);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'دسترسی غیرمجاز' });
    }

    const review = await Review.findByPk(req.params.id);
    if (!review) {
      return res.status(404).json({ success: false, message: 'نظر یافت نشد' });
    }

    await review.destroy();
    res.json({ success: true, message: 'نظر رد و حذف شد' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
