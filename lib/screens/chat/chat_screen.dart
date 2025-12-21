import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_manager.dart';
import '../../services/media_cache_service.dart';
import '../../widgets/cached_media.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String recipientAvatar;
  final String? recipientImage;

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatar,
    this.recipientImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  late RecorderController _recorderController;
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  bool _isBlocked = false;
  bool _isOnline = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _lastSeen;
  Timer? _refreshTimer;
  Timer? _typingTimer;
  int? _myUserId;
  Map<String, dynamic>? _replyTo;
  
  // Pagination
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // جلوگیری از نمایش اعلان در این چت
    NotificationManager.setCurrentChat(widget.recipientId);
    _recorderController = RecorderController();
    
    // لیسنر برای اسکرول به بالا
    _scrollController.addListener(_onScroll);
    
    _init();
  }
  
  // وقتی به بالای لیست رسید، پیام‌های قدیمی‌تر رو لود کن
  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && 
        !_isLoadingMore && 
        _hasMoreMessages &&
        !_isLoading) {
      _loadMoreMessages();
    }
  }
  
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final olderMessages = await ApiService.getMessages(
        int.parse(widget.recipientId),
        page: _currentPage + 1,
      );
      
      if (olderMessages.isEmpty) {
        setState(() => _hasMoreMessages = false);
      } else {
        setState(() {
          _currentPage++;
          // پیام‌های قدیمی‌تر رو به اول لیست اضافه کن
          _messages.insertAll(0, olderMessages);
        });
      }
    } catch (e) {
      debugPrint('❌ Load more messages error: $e');
    }
    
    setState(() => _isLoadingMore = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ApiService.setOnline();
    } else if (state == AppLifecycleState.paused) {
      ApiService.setOffline();
    }
  }

  Future<void> _init() async {
    // اول userId رو بگیر (سریع)
    _myUserId = await ApiService.getCurrentUserId();
    
    // اتصال به WebSocket (بدون await)
    if (_myUserId != null) {
      SocketService.connect(_myUserId!);
      SocketService.onNewMessage = _onNewMessageReceived;
      SocketService.onUserTyping = _onUserTypingReceived;
      SocketService.onMessageDelivered = _onMessageDelivered;
      SocketService.onMessageRead = _onMessageRead;
      SocketService.onMessageEdited = _onMessageEdited;
      SocketService.onMessageDeleted = _onMessageDeleted;
    }
    
    // لود موازی بدون بلاک کردن UI - با timeout
    Future.wait([
      _loadUserInfo().timeout(const Duration(seconds: 10), onTimeout: () {}),
      _loadMessages().timeout(const Duration(seconds: 15), onTimeout: () {
        if (mounted) setState(() => _isLoading = false);
      }),
    ]);
    
    // setOnline بدون await
    ApiService.setOnline();
    
    // فقط برای بکاپ، هر 60 ثانیه چک کن
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _loadMessages(showLoading: false);
    });
  }
  
  void _onNewMessageReceived(Map<String, dynamic> message) {
    final senderId = message['senderId']?.toString();
    if (senderId == widget.recipientId && mounted) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
      
      final messageId = message['id'];
      if (messageId != null) {
        ApiService.markMessageRead(messageId);
      }
    }
  }
  
  void _onUserTypingReceived(int senderId) {
    if (senderId.toString() == widget.recipientId && mounted) {
      setState(() => _isTyping = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  // وقتی پیام تحویل داده شد
  void _onMessageDelivered(int messageId) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['isDelivered'] = true;
        }
      });
    }
  }

  // وقتی پیام خوانده شد
  void _onMessageRead(int messageId) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['isDelivered'] = true;
          _messages[index]['isRead'] = true;
        }
      });
    }
  }

  // وقتی پیام ویرایش شد
  void _onMessageEdited(int messageId, String newMessage) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['message'] = newMessage;
          _messages[index]['isEdited'] = true;
        }
      });
    }
  }

  // وقتی پیام حذف شد
  void _onMessageDeleted(int messageId) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['isDeleted'] = true;
          _messages[index]['message'] = 'این پیام حذف شده است';
        }
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final user = await ApiService.getChatUser(int.parse(widget.recipientId));
    if (user != null && mounted) {
      setState(() {
        _isOnline = user['isOnline'] == true;
        _lastSeen = user['lastSeen'];
        _isBlocked = user['isBlocked'] == true;
      });
    }
  }


  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      final messages = await ApiService.getMessages(int.parse(widget.recipientId));
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _currentPage = 1;
          _hasMoreMessages = messages.length >= 50;
        });
        if (showLoading) _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTextChanged(String text) {
    // فقط یک بار در هر 2 ثانیه typing ارسال کن
    if (_typingTimer?.isActive != true) {
      ApiService.sendTyping(int.parse(widget.recipientId));
      _typingTimer = Timer(const Duration(seconds: 2), () {});
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text.trim();
    _messageController.clear();

    debugPrint('📨 Sending message to recipientId: ${widget.recipientId}');
    debugPrint('📨 My userId: $_myUserId');

    // چک کردن معتبر بودن recipientId
    final recipientIdInt = int.tryParse(widget.recipientId);
    if (recipientIdInt == null || recipientIdInt <= 0) {
      debugPrint('❌ Invalid recipientId: ${widget.recipientId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا: شناسه گیرنده نامعتبر است'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // ذخیره replyToId قبل از پاک کردن
    final replyToId = _replyTo?['id'];

    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'senderId': _myUserId,
        'message': message,
        'messageType': 'text',
        'createdAt': DateTime.now().toIso8601String(),
        'replyTo': _replyTo,
      });
      _replyTo = null;
    });
    _scrollToBottom();

    final success = await ApiService.sendMessage(
      recipientIdInt,
      message,
      replyToId: replyToId,
    );
    debugPrint('📨 Send result: $success');
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ارسال پیام'), backgroundColor: Colors.red),
      );
    }
  }


  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) await _sendMedia(File(image.path), 'image');
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) await _sendMedia(File(video.path), 'video');
  }

  Future<void> _sendMedia(File file, String type) async {
    debugPrint('📤 Sending media: type=$type, path=${file.path}');
    
    // چک کردن وجود فایل
    if (!await file.exists()) {
      debugPrint('❌ File does not exist: ${file.path}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فایل یافت نشد'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    final fileSize = await file.length();
    debugPrint('📤 File size: $fileSize bytes');
    
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'senderId': _myUserId,
        'messageType': type,
        'mediaUrl': file.path,
        'createdAt': DateTime.now().toIso8601String(),
        'isLocal': true,
      });
    });
    _scrollToBottom();

    debugPrint('📤 Calling ApiService.sendChatMedia...');
    final result = await ApiService.sendChatMedia(
      int.parse(widget.recipientId),
      file,
      type,
      replyToId: _replyTo?['id'],
    );
    debugPrint('📤 Result: $result');
    
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ارسال فایل'), backgroundColor: Colors.red),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل ارسال شد'), backgroundColor: Colors.green),
      );
    }
    setState(() => _replyTo = null);
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بلاک کردن'),
        content: Text('آیا می‌خواهید ${widget.recipientName} را بلاک کنید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('خیر')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('بله')),
        ],
      ),
    );
    if (confirm == true) {
      final success = await ApiService.blockUser(int.parse(widget.recipientId));
      if (success && mounted) {
        setState(() => _isBlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کاربر بلاک شد')),
        );
      }
    }
  }

  Future<void> _unblockUser() async {
    final success = await ApiService.unblockUser(int.parse(widget.recipientId));
    if (success && mounted) {
      setState(() => _isBlocked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کاربر آنبلاک شد')),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      var time = DateTime.parse(dateStr);
      // تبدیل UTC به وقت ایران (+3:30)
      if (time.isUtc || !dateStr.contains('+')) {
        time = time.toLocal();
      }
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _formatLastSeen(String? dateStr) {
    if (dateStr == null) return '';
    try {
      var time = DateTime.parse(dateStr);
      // تبدیل UTC به وقت محلی
      if (time.isUtc || !dateStr.contains('+')) {
        time = time.toLocal();
      }
      final diff = DateTime.now().difference(time);
      if (diff.inMinutes < 1) return 'همین الان';
      if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
      if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
      return '${diff.inDays} روز پیش';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    // اجازه نمایش اعلان دوباره
    NotificationManager.setCurrentChat(null);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _recorderController.dispose();
    ApiService.setOffline();
    super.dispose();
  }

  // شروع ضبط صدا
  Future<void> _startRecording() async {
    try {
      // چک کردن و درخواست permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دسترسی به میکروفون داده نشده'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.aac');
      
      debugPrint('🎤 Starting recording at: $path');
      await _recorderController.record(path: path);
      
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      
      // تایمر برای نمایش مدت زمان ضبط
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });
      
      debugPrint('🎤 Recording started');
    } catch (e) {
      debugPrint('❌ Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ضبط صدا: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // توقف ضبط و ارسال
  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      debugPrint('🎤 Stopping recording...');
      final path = await _recorderController.stop();
      debugPrint('🎤 Recording stopped, path: $path');
      
      setState(() => _isRecording = false);
      
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('🎤 Voice file size: $size bytes');
          if (size > 0) {
            await _sendMedia(file, 'voice');
          } else {
            debugPrint('❌ Voice file is empty');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('فایل صوتی خالی است'), backgroundColor: Colors.red),
              );
            }
          }
        } else {
          debugPrint('❌ Voice file does not exist');
        }
      } else {
        debugPrint('❌ No path returned from recorder');
      }
    } catch (e) {
      debugPrint('❌ Stop recording error: $e');
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال صدا: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // لغو ضبط
  void _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _recorderController.stop();
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      debugPrint('❌ Cancel recording error: $e');
      setState(() => _isRecording = false);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1976D2),
                    backgroundImage: (widget.recipientImage != null && widget.recipientImage!.isNotEmpty)
                        ? NetworkImage('${ApiService.serverUrl}${widget.recipientImage}')
                        : null,
                    child: (widget.recipientImage == null || widget.recipientImage!.isEmpty)
                        ? Text(widget.recipientAvatar, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  if (_isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipientName, style: const TextStyle(fontSize: 16)),
                  Text(
                    _isTyping ? 'در حال نوشتن...' : (_isOnline ? 'آنلاین' : _formatLastSeen(_lastSeen)),
                    style: TextStyle(fontSize: 12, color: _isTyping ? Colors.green : Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'block') _blockUser();
                if (value == 'unblock') _unblockUser();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: _isBlocked ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(_isBlocked ? Icons.check_circle : Icons.block, color: _isBlocked ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Text(_isBlocked ? 'آنبلاک کردن' : 'بلاک کردن'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isBlocked)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('این کاربر بلاک شده است', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            Expanded(child: _buildMessageList()),
            if (_replyTo != null) _buildReplyPreview(),
            if (!_isBlocked) _buildInputArea(),
          ],
        ),
      ),
    );
  }


  Widget _buildMessageList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.textGrey),
            const SizedBox(height: 16),
            Text('هنوز پیامی ارسال نشده', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      cacheExtent: 1000,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        // نمایش loading در بالای لیست
        if (_isLoadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        
        final messageIndex = _isLoadingMore ? index - 1 : index;
        final message = _messages[messageIndex];
        // استفاده از key برای جلوگیری از rebuild غیرضروری
        return RepaintBoundary(
          key: ValueKey(message['id'] ?? messageIndex),
          child: _MessageBubble(
            message: message,
            isMe: message['senderId']?.toString() == _myUserId?.toString(),
            onLongPress: () => _showMessageOptions(message),
            onReply: () => setState(() => _replyTo = message),
            formatTime: _formatTime,
          ),
        );
      },
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final senderId = message['senderId']?.toString() ?? '';
    final isMe = senderId == _myUserId?.toString();
    final messageType = message['messageType'] ?? 'text';
    final isDeleted = message['isDeleted'] == true;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // پاسخ دادن
            if (!isDeleted)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('پاسخ دادن'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyTo = message);
                },
              ),
            // کپی متن
            if (messageType == 'text' && !isDeleted)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('کپی متن'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Clipboard.setData(ClipboardData(text: message['message'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('متن کپی شد')),
                  );
                },
              ),
            // ویرایش پیام (فقط برای پیام‌های خودم و متنی)
            if (isMe && messageType == 'text' && !isDeleted)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('ویرایش پیام'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMessageDialog(message);
                },
              ),
            // حذف پیام (فقط برای پیام‌های خودم)
            if (isMe && !isDeleted)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف پیام'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  // دیالوگ ویرایش پیام
  void _showEditMessageDialog(Map<String, dynamic> message) {
    final controller = TextEditingController(text: message['message'] ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ویرایش پیام'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'متن جدید پیام...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newMessage = controller.text.trim();
              if (newMessage.isEmpty) return;
              
              Navigator.pop(ctx);
              
              final messageId = message['id'];
              if (messageId == null) return;
              
              final success = await ApiService.editMessage(
                messageId, 
                newMessage,
                recipientId: int.tryParse(widget.recipientId),
              );
              if (success && mounted) {
                // آپدیت لوکال
                setState(() {
                  final index = _messages.indexWhere((m) => m['id'] == messageId);
                  if (index != -1) {
                    _messages[index]['message'] = newMessage;
                    _messages[index]['isEdited'] = true;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('پیام ویرایش شد'), backgroundColor: Colors.green),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خطا در ویرایش پیام'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  // تایید حذف پیام
  void _confirmDeleteMessage(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف پیام'),
        content: const Text('آیا از حذف این پیام مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('خیر'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              
              final messageId = message['id'];
              if (messageId == null) return;
              
              final success = await ApiService.deleteMessage(messageId);
              if (success && mounted) {
                // آپدیت لوکال
                setState(() {
                  final index = _messages.indexWhere((m) => m['id'] == messageId);
                  if (index != -1) {
                    _messages[index]['isDeleted'] = true;
                    _messages[index]['message'] = 'این پیام حذف شده است';
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('پیام حذف شد')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خطا در حذف پیام'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('بله، حذف شود', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Container(width: 4, height: 40, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('پاسخ به:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(_replyTo?['message'] ?? '[${_replyTo?['messageType']}]', maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    // حالت ضبط صدا
    if (_isRecording) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.red.shade50,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _cancelRecording,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _stopRecording,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // حالت عادی
    final hasText = _messageController.text.trim().isNotEmpty;
    
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, size: 22),
              onPressed: _showAttachmentOptions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: (text) {
                  _onTextChanged(text);
                  setState(() {}); // برای آپدیت دکمه‌ها
                },
                decoration: InputDecoration(
                  hintText: 'پیام...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: 4),
            // دکمه میکروفون یا ارسال
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: hasText
                  ? Container(
                      key: const ValueKey('send'),
                      decoration: const BoxDecoration(color: Color(0xFF1976D2), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _sendMessage,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    )
                  : Container(
                      key: const ValueKey('mic'),
                      decoration: BoxDecoration(color: Colors.orange.shade400, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.mic, color: Colors.white, size: 20),
                        onPressed: _startRecording,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('تصویر از گالری'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('عکس با دوربین'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text('ویدیو از گالری'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call, color: Colors.orange),
              title: const Text('فیلم با دوربین'),
              onTap: () {
                Navigator.pop(ctx);
                _recordVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  // گرفتن عکس با دوربین
  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) await _sendMedia(File(image.path), 'image');
  }

  // گرفتن فیلم با دوربین
  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) await _sendMedia(File(video.path), 'video');
  }
}

// صفحه پخش ویدیو
class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final bool isLocal;
  const VideoPlayerScreen({super.key, required this.url, required this.isLocal});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      debugPrint('🎥 Loading video: ${widget.url}');
      if (widget.isLocal) {
        _controller = VideoPlayerController.file(File(widget.url));
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }
      await _controller!.initialize();
      setState(() {});
      _controller!.play();
    } catch (e) {
      debugPrint('❌ Video error: $e');
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('پخش ویدیو', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _isError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text('خطا در پخش ویدیو', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text('URL: ${widget.url}', style: const TextStyle(color: Colors.blue, fontSize: 10), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                  ),
                ],
              )
            : _controller != null && _controller!.value.isInitialized
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        if (!_controller!.value.isPlaying)
                          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 80),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// صفحه نمایش عکس بزرگ
class FullImageScreen extends StatelessWidget {
  final String url;
  final bool isLocal;
  
  const FullImageScreen({super.key, required this.url, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'image_$url',
            child: isLocal
                ? Image.file(File(url), fit: BoxFit.contain)
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                  ),
          ),
        ),
      ),
    );
  }
}

// پلیر پیام صوتی با کنترل‌های بهتر
class _VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  final bool isLocal;

  const _VoiceMessagePlayer({required this.url, required this.isMe, required this.isLocal});

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final ap.AudioPlayer _player = ap.AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  void _setupPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == ap.PlayerState.playing);
      }
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (widget.isLocal) {
        await _player.play(ap.DeviceFileSource(widget.url));
      } else {
        await _player.play(ap.UrlSource(widget.url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppTheme.primaryGreen;
    final bgColor = widget.isMe ? Colors.white24 : Colors.grey.shade300;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: color,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: color,
                    inactiveTrackColor: bgColor,
                    thumbColor: color,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isMe ? Colors.white70 : AppTheme.textGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ویجت بهینه‌شده برای هر پیام - جدا از لیست اصلی برای جلوگیری از rebuild
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final String Function(String?) formatTime;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onLongPress,
    required this.onReply,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final messageType = message['messageType'] ?? 'text';
    final replyTo = message['replyTo'] as Map<String, dynamic>?;
    final isDeleted = message['isDeleted'] == true;
    final isEdited = message['isEdited'] == true;
    final isDelivered = message['isDelivered'] == true;
    final isRead = message['isRead'] == true;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (replyTo != null) _buildReplyBubble(replyTo, isMe),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, size: 14, color: isMe ? Colors.white54 : AppTheme.textGrey),
                          const SizedBox(width: 4),
                          Text(
                            'این پیام حذف شده است',
                            style: TextStyle(
                              color: isMe ? Colors.white54 : AppTheme.textGrey,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    else
                      _buildMessageContent(context, message, messageType, isMe),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEdited && !isDeleted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'ویرایش شده',
                              style: TextStyle(
                                color: isMe ? Colors.white54 : AppTheme.textGrey,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        Text(
                          formatTime(message['createdAt']),
                          style: TextStyle(color: isMe ? Colors.white70 : AppTheme.textGrey, fontSize: 11),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildMessageStatus(isDelivered, isRead),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageStatus(bool isDelivered, bool isRead) {
    if (isRead) {
      return Icon(Icons.done_all, size: 16, color: Colors.lightBlueAccent.shade100);
    } else if (isDelivered) {
      return const Icon(Icons.done_all, size: 16, color: Colors.white70);
    } else {
      return const Icon(Icons.done, size: 16, color: Colors.white70);
    }
  }

  Widget _buildReplyBubble(Map<String, dynamic> reply, bool isMe) {
    final replyMessage = reply['message'] ?? '';
    final replyType = reply['messageType'] ?? 'text';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: isMe ? Colors.white : AppTheme.primaryGreen, width: 3)),
      ),
      child: Text(
        replyType == 'text' && replyMessage.isNotEmpty 
            ? (replyMessage.length > 50 ? '${replyMessage.substring(0, 50)}...' : replyMessage)
            : '[$replyType]',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : AppTheme.textGrey),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Map<String, dynamic> message, String type, bool isMe) {
    final mediaUrl = message['mediaUrl'] ?? '';
    final isLocal = message['isLocal'] == true;
    final fullUrl = isLocal ? mediaUrl : '${ApiService.serverUrl}$mediaUrl';

    switch (type) {
      case 'image':
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FullImageScreen(url: fullUrl, isLocal: isLocal)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isLocal
                ? Image.file(File(mediaUrl), width: 200, fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: fullUrl,
                    width: 200,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    placeholder: Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey.shade300,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
          ),
        );
      case 'video':
        if (isLocal) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: fullUrl, isLocal: true)),
            ),
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                ],
              ),
            ),
          );
        }
        return CachedVideo(
          videoUrl: fullUrl,
          width: 200,
          height: 150,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: fullUrl, isLocal: false)),
          ),
        );
      case 'voice':
        return _CachedVoicePlayer(url: fullUrl, isMe: isMe, isLocal: isLocal);
      default:
        return Text(message['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : AppTheme.textDark, fontSize: 15));
    }
  }
}

// پلیر پیام صوتی با کش
class _CachedVoicePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  final bool isLocal;

  const _CachedVoicePlayer({required this.url, required this.isMe, required this.isLocal});

  @override
  State<_CachedVoicePlayer> createState() => _CachedVoicePlayerState();
}

class _CachedVoicePlayerState extends State<_CachedVoicePlayer> {
  final ap.AudioPlayer _player = ap.AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _cachedPath;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
    if (!widget.isLocal) {
      _cacheAudio();
    }
  }

  void _setupPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == ap.PlayerState.playing);
      }
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _cacheAudio() async {
    // اول چک کن کش شده یا نه
    var path = await MediaCacheService.getCachedPath(
      widget.url,
      type: MediaType.audio,
    );
    
    if (path != null) {
      if (mounted) setState(() => _cachedPath = path);
      return;
    }

    // دانلود و کش کن با نمایش پیشرفت
    setState(() {
      _isLoading = true;
      _downloadProgress = 0;
    });
    path = await MediaCacheService.downloadAndCache(
      widget.url,
      type: MediaType.audio,
      onProgress: (progress) {
        if (mounted) setState(() => _downloadProgress = progress);
      },
    );
    if (mounted) {
      setState(() {
        _cachedPath = path;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (widget.isLocal) {
        await _player.play(ap.DeviceFileSource(widget.url));
      } else if (_cachedPath != null) {
        await _player.play(ap.DeviceFileSource(_cachedPath!));
      } else {
        await _player.play(ap.UrlSource(widget.url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppTheme.primaryGreen;
    final bgColor = widget.isMe ? Colors.white24 : Colors.grey.shade300;
    
    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2, 
              color: color,
              value: _downloadProgress > 0 ? _downloadProgress : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _downloadProgress > 0 ? '${(_downloadProgress * 100).toInt()}%' : 'در حال دانلود...',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: color,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: color,
                    inactiveTrackColor: bgColor,
                    thumbColor: color,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.isMe ? Colors.white70 : AppTheme.textGrey,
                    ),
                  ),
                  if (_cachedPath != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle, size: 10, color: Colors.green.shade400),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
