const express = require('express');
const router = express.Router();
const { Op } = require('sequelize');
const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { Chat, User, BlockedUser } = require('../models');
const { auth } = require('../middleware/auth');

// تنظیمات آپلود فایل
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/chat/'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  }
});
const upload = multer({ 
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|mp4|mov|avi|mp3|wav|ogg|m4a|aac|webm|3gp/;
    const ext = allowed.test(path.extname(file.originalname).toLowerCase());
    const mime = allowed.test(file.mimetype);
    console.log('📎 File filter:', file.originalname, file.mimetype, 'ext:', ext, 'mime:', mime);
    cb(null, ext || mime);
  }
});

// آپدیت وضعیت آنلاین
router.post('/online', auth, async (req, res) => {
  try {
    await User.update({ isOnline: true, lastSeen: new Date() }, { where: { id: req.userId } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/offline', auth, async (req, res) => {
  try {
    await User.update({ isOnline: false, lastSeen: new Date() }, { where: { id: req.userId } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// وضعیت تایپ کردن
const typingUsers = new Map();
router.post('/typing/:receiverId', auth, (req, res) => {
  const key = `${req.userId}-${req.params.receiverId}`;
  typingUsers.set(key, Date.now());
  res.json({ success: true });
});

router.get('/typing/:senderId', auth, (req, res) => {
  const key = `${req.params.senderId}-${req.userId}`;
  const lastTyping = typingUsers.get(key);
  const isTyping = lastTyping && (Date.now() - lastTyping) < 3000;
  res.json({ success: true, isTyping });
});


// بلاک کردن کاربر
router.post('/block/:userId', auth, async (req, res) => {
  try {
    const [blocked, created] = await BlockedUser.findOrCreate({
      where: { userId: req.userId, blockedUserId: req.params.userId }
    });
    res.json({ success: true, message: created ? 'کاربر بلاک شد' : 'قبلاً بلاک شده' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/block/:userId', auth, async (req, res) => {
  try {
    await BlockedUser.destroy({ where: { userId: req.userId, blockedUserId: req.params.userId } });
    res.json({ success: true, message: 'کاربر آنبلاک شد' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/blocked', auth, async (req, res) => {
  try {
    const blocked = await BlockedUser.findAll({
      where: { userId: req.userId },
      include: [{ model: User, as: 'blockedUser', attributes: ['id', 'name', 'phone', 'profileImage'] }]
    });
    res.json({ success: true, data: blocked.map(b => b.blockedUser) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// چک کردن بلاک بودن
router.get('/is-blocked/:userId', auth, async (req, res) => {
  try {
    const blocked = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { userId: req.userId, blockedUserId: req.params.userId },
          { userId: req.params.userId, blockedUserId: req.userId }
        ]
      }
    });
    res.json({ success: true, isBlocked: !!blocked });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت لیست مکالمات
router.get('/conversations', auth, async (req, res) => {
  try {
    const blockedIds = (await BlockedUser.findAll({
      where: { [Op.or]: [{ userId: req.userId }, { blockedUserId: req.userId }] }
    })).map(b => b.userId === req.userId ? b.blockedUserId : b.userId);

    const allChats = await Chat.findAll({
      where: {
        [Op.or]: [{ senderId: req.userId }, { receiverId: req.userId }]
      },
      order: [['createdAt', 'DESC']]
    });

    const partnerIds = [...new Set(allChats.map(c => 
      c.senderId === req.userId ? c.receiverId : c.senderId
    ))].filter(id => !blockedIds.includes(id));

    const partners = await User.findAll({
      where: { id: partnerIds },
      attributes: ['id', 'name', 'phone', 'profileImage', 'isOnline', 'lastSeen']
    });

    const result = await Promise.all(partners.map(async (partner) => {
      const lastMessage = await Chat.findOne({
        where: {
          [Op.or]: [
            { senderId: req.userId, receiverId: partner.id },
            { senderId: partner.id, receiverId: req.userId }
          ]
        },
        order: [['createdAt', 'DESC']]
      });

      const unreadCount = await Chat.count({
        where: { senderId: partner.id, receiverId: req.userId, isRead: false }
      });

      return {
        user: {
          id: partner.id,
          name: partner.name || 'کاربر',
          phone: partner.phone,
          profileImage: partner.profileImage,
          isOnline: partner.isOnline,
          lastSeen: partner.lastSeen
        },
        message: lastMessage?.message || (lastMessage?.messageType !== 'text' ? `[${lastMessage?.messageType}]` : ''),
        messageType: lastMessage?.messageType,
        createdAt: lastMessage?.createdAt,
        unreadCount
      };
    }));

    result.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});


// دریافت اطلاعات کاربر چت
router.get('/user/:userId', auth, async (req, res) => {
  try {
    const user = await User.findByPk(req.params.userId, {
      attributes: ['id', 'name', 'phone', 'profileImage', 'isOnline', 'lastSeen']
    });
    if (!user) return res.status(404).json({ success: false, message: 'کاربر یافت نشد' });
    
    const isBlocked = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { userId: req.userId, blockedUserId: req.params.userId },
          { userId: req.params.userId, blockedUserId: req.userId }
        ]
      }
    });
    
    res.json({ success: true, data: { ...user.toJSON(), isBlocked: !!isBlocked } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// دریافت پیام‌های یک مکالمه
router.get('/messages/:recipientId', auth, async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const recipientId = req.params.recipientId;

    const { count, rows } = await Chat.findAndCountAll({
      where: {
        [Op.or]: [
          { senderId: req.userId, receiverId: recipientId },
          { senderId: recipientId, receiverId: req.userId }
        ]
      },
      include: [{ model: Chat, as: 'replyTo', attributes: ['id', 'message', 'senderId', 'messageType'] }],
      order: [['createdAt', 'DESC']],
      offset: (page - 1) * limit,
      limit: Number(limit)
    });

    await Chat.update(
      { isRead: true },
      { where: { senderId: recipientId, receiverId: req.userId, isRead: false } }
    );

    res.json({ success: true, data: rows.reverse(), total: count });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ارسال پیام متنی
router.post('/send', auth, async (req, res) => {
  try {
    console.log('📨 ارسال پیام:', req.body, 'از کاربر:', req.userId);
    const { receiverId, message, replyToId, isEncrypted } = req.body;

    const isBlocked = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { userId: req.userId, blockedUserId: receiverId },
          { userId: receiverId, blockedUserId: req.userId }
        ]
      }
    });
    if (isBlocked) return res.status(403).json({ success: false, message: 'امکان ارسال پیام وجود ندارد' });

    const chat = await Chat.create({
      senderId: req.userId,
      receiverId,
      message,
      messageType: 'text',
      replyToId,
      isEncrypted: isEncrypted || false
    });

    const fullChat = await Chat.findByPk(chat.id, {
      include: [{ model: Chat, as: 'replyTo', attributes: ['id', 'message', 'senderId', 'messageType'] }]
    });

    // ارسال پیام از طریق WebSocket
    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');
    const receiverSocket = onlineUsers.get(Number(receiverId));
    
    if (receiverSocket && io) {
      io.to(receiverSocket).emit('newMessage', {
        ...fullChat.toJSON(),
        senderId: req.userId
      });
      console.log('🔌 پیام از طریق WebSocket ارسال شد');
    }

    console.log('✅ پیام ارسال شد:', fullChat.id);
    res.status(201).json({ success: true, data: fullChat });
  } catch (error) {
    console.error('❌ خطا در ارسال پیام:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ارسال فایل (عکس/ویدیو/صدا)
router.post('/send-media', auth, upload.single('file'), async (req, res) => {
  try {
    console.log('📎 آپلود مدیا - body:', req.body);
    console.log('📎 آپلود مدیا - file:', req.file);
    console.log('📎 آپلود مدیا - userId:', req.userId);
    
    const { receiverId, messageType, replyToId, message } = req.body;
    
    if (!req.file) {
      console.log('❌ فایل ارسال نشده - headers:', req.headers);
      return res.status(400).json({ success: false, message: 'فایل ارسال نشده' });
    }
    
    if (!receiverId) {
      console.log('❌ receiverId ارسال نشده');
      return res.status(400).json({ success: false, message: 'receiverId ارسال نشده' });
    }

    const isBlocked = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { userId: req.userId, blockedUserId: receiverId },
          { userId: receiverId, blockedUserId: req.userId }
        ]
      }
    });
    if (isBlocked) return res.status(403).json({ success: false, message: 'امکان ارسال پیام وجود ندارد' });

    const chat = await Chat.create({
      senderId: req.userId,
      receiverId: Number(receiverId),
      message: message || null,
      messageType: messageType || 'image',
      mediaUrl: `/uploads/chat/${req.file.filename}`,
      replyToId: replyToId ? Number(replyToId) : null
    });

    const fullChat = await Chat.findByPk(chat.id, {
      include: [{ model: Chat, as: 'replyTo', attributes: ['id', 'message', 'senderId', 'messageType'] }]
    });

    // ارسال پیام از طریق WebSocket
    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');
    const receiverSocket = onlineUsers.get(Number(receiverId));
    
    if (receiverSocket && io) {
      io.to(receiverSocket).emit('newMessage', {
        ...fullChat.toJSON(),
        senderId: req.userId
      });
      console.log('🔌 مدیا از طریق WebSocket ارسال شد');
    }

    console.log('✅ مدیا آپلود شد:', fullChat.id, fullChat.mediaUrl);
    res.status(201).json({ success: true, data: fullChat });
  } catch (error) {
    console.error('❌ خطا در آپلود مدیا:', error);
    console.error('❌ Stack:', error.stack);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ویرایش پیام
router.put('/message/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { message } = req.body;
    
    const chat = await Chat.findByPk(messageId);
    if (!chat) {
      return res.status(404).json({ success: false, message: 'پیام یافت نشد' });
    }
    
    // فقط فرستنده میتونه ویرایش کنه
    if (chat.senderId !== req.userId) {
      return res.status(403).json({ success: false, message: 'شما اجازه ویرایش این پیام را ندارید' });
    }
    
    // فقط پیام متنی قابل ویرایشه
    if (chat.messageType !== 'text') {
      return res.status(400).json({ success: false, message: 'فقط پیام‌های متنی قابل ویرایش هستند' });
    }
    
    await chat.update({ message, isEdited: true });
    
    // اطلاع‌رسانی از طریق WebSocket
    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');
    const receiverSocket = onlineUsers.get(chat.receiverId);
    
    if (receiverSocket && io) {
      io.to(receiverSocket).emit('messageEdited', {
        messageId: chat.id,
        message,
        isEdited: true
      });
    }
    
    res.json({ success: true, data: chat });
  } catch (error) {
    console.error('❌ خطا در ویرایش پیام:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// حذف پیام
router.delete('/message/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    
    const chat = await Chat.findByPk(messageId);
    if (!chat) {
      return res.status(404).json({ success: false, message: 'پیام یافت نشد' });
    }
    
    // فقط فرستنده میتونه حذف کنه
    if (chat.senderId !== req.userId) {
      return res.status(403).json({ success: false, message: 'شما اجازه حذف این پیام را ندارید' });
    }
    
    await chat.update({ isDeleted: true, message: 'این پیام حذف شده است' });
    
    // اطلاع‌رسانی از طریق WebSocket
    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');
    const receiverSocket = onlineUsers.get(chat.receiverId);
    
    if (receiverSocket && io) {
      io.to(receiverSocket).emit('messageDeleted', {
        messageId: chat.id
      });
    }
    
    res.json({ success: true, message: 'پیام حذف شد' });
  } catch (error) {
    console.error('❌ خطا در حذف پیام:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// علامت‌گذاری پیام به عنوان تحویل داده شده
router.put('/delivered/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    
    const chat = await Chat.findByPk(messageId);
    if (!chat) {
      return res.status(404).json({ success: false, message: 'پیام یافت نشد' });
    }
    
    // فقط گیرنده میتونه تحویل رو تایید کنه
    if (chat.receiverId !== req.userId) {
      return res.status(403).json({ success: false, message: 'دسترسی غیرمجاز' });
    }
    
    await chat.update({ isDelivered: true });
    
    // اطلاع‌رسانی به فرستنده
    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');
    const senderSocket = onlineUsers.get(chat.senderId);
    
    if (senderSocket && io) {
      io.to(senderSocket).emit('messageDelivered', { messageId: chat.id });
    }
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// علامت‌گذاری پیام به عنوان خوانده شده
router.put('/read/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    
    const chat = await Chat.findByPk(messageId);
    if (!chat) {
      return res.status(404).json({ success: false, message: 'پیام یافت نشد' });
    }
    
    // فقط گیرنده میتونه خوانده شدن رو تایید کنه
    if (chat.receiverId !== req.userId) {
      return res.status(403).json({ success: false, message: 'دسترسی غیرمجاز' });
    }
    
    await chat.update({ isRead: true, isDelivered: true });
    
    // اطلاع‌رسانی به فرستنده
    const io = req.app.get('io');
    const onlineUsers = req.app.get('onlineUsers');
    const senderSocket = onlineUsers.get(chat.senderId);
    
    if (senderSocket && io) {
      io.to(senderSocket).emit('messageRead', { messageId: chat.id });
    }
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
