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
import '../../services/encryption_service.dart';
import '../../services/notification_manager.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String recipientAvatar;

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatar,
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
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _lastSeen;
  Timer? _refreshTimer;
  Timer? _typingTimer;
  int? _myUserId;
  Map<String, dynamic>? _replyTo;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // جلوگیری از نمایش اعلان در این چت
    NotificationManager.setCurrentChat(widget.recipientId);
    _recorderController = RecorderController();
    _init();
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
    _myUserId = await ApiService.getCurrentUserId();
    ApiService.setOnline();
    
    // اتصال به WebSocket
    if (_myUserId != null) {
      SocketService.connect(_myUserId!);
      SocketService.onNewMessage = _onNewMessageReceived;
      SocketService.onUserTyping = _onUserTypingReceived;
    }
    
    await _loadUserInfo();
    await _loadMessages();
    
    // فقط برای بکاپ، هر 10 ثانیه چک کن
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadMessages(showLoading: false);
    });
  }
  
  void _onNewMessageReceived(Map<String, dynamic> message) async {
    final senderId = message['senderId']?.toString();
    if (senderId == widget.recipientId && mounted) {
      // رمزگشایی پیام اگه رمزشده باشه
      if (message['isEncrypted'] == true && message['message'] != null) {
        try {
          final decrypted = await EncryptionService.decryptMessage(
            message['message'],
            int.parse(widget.recipientId),
          );
          message['message'] = decrypted;
        } catch (e) {
          debugPrint('❌ WebSocket decrypt error: $e');
        }
      }
      
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
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

  Future<void> _checkTyping() async {
    final typing = await ApiService.isTyping(int.parse(widget.recipientId));
    if (mounted && typing != _isTyping) {
      setState(() => _isTyping = typing);
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
        });
        if (showLoading) _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTextChanged(String text) {
    _typingTimer?.cancel();
    ApiService.sendTyping(int.parse(widget.recipientId));
    _typingTimer = Timer(const Duration(seconds: 2), () {});
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
      final time = DateTime.parse(dateStr);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _formatLastSeen(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final time = DateTime.parse(dateStr);
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
        _recordingPath = path;
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
        _recordingPath = null;
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
                    child: Text(widget.recipientAvatar, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final senderId = message['senderId']?.toString() ?? '';
    final isMe = senderId == _myUserId?.toString();
    final messageType = message['messageType'] ?? 'text';
    final replyTo = message['replyTo'] as Map<String, dynamic>?;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
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
                    _buildMessageContent(message, messageType, isMe),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message['createdAt']),
                      style: TextStyle(color: isMe ? Colors.white70 : AppTheme.textGrey, fontSize: 11),
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

  Widget _buildReplyBubble(Map<String, dynamic> reply, bool isMe) {
    final message = reply['message'] ?? '';
    final messageType = reply['messageType'] ?? 'text';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: isMe ? Colors.white : AppTheme.primaryGreen, width: 3)),
      ),
      child: messageType == 'text' && message.isNotEmpty
          ? FutureBuilder<String>(
              future: _decryptIfNeeded(message),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : AppTheme.textGrey),
                );
              },
            )
          : Text(
              message.isNotEmpty ? message : '[$messageType]',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : AppTheme.textGrey),
            ),
    );
  }

  // چک کردن و رمزگشایی متن اگه لازم باشه
  Future<String> _decryptIfNeeded(String text) async {
    if (text.isEmpty) return text;
    // چک کردن اینکه متن شبیه Base64 رمزشده هست
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (text.length > 5 && base64Pattern.hasMatch(text) && (text.endsWith('=') || text.contains('/'))) {
      try {
        final decrypted = await EncryptionService.decryptMessage(text, int.parse(widget.recipientId));
        return decrypted;
      } catch (e) {
        return text;
      }
    }
    return text;
  }

  Widget _buildMessageContent(Map<String, dynamic> message, String type, bool isMe) {
    final mediaUrl = message['mediaUrl'] ?? '';
    final isLocal = message['isLocal'] == true;
    final fullUrl = isLocal ? mediaUrl : 'http://10.0.2.2:3000$mediaUrl';

    switch (type) {
      case 'image':
        return GestureDetector(
          onTap: () => _showFullImage(fullUrl, isLocal),
          child: Hero(
            tag: 'image_$mediaUrl',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isLocal
                  ? Image.file(File(mediaUrl), width: 200, fit: BoxFit.cover)
                  : Image.network(fullUrl, width: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
            ),
          ),
        );
      case 'video':
        return _buildVideoPlayer(isLocal ? mediaUrl : fullUrl, isLocal);
      case 'voice':
        return _VoiceMessagePlayer(url: fullUrl, isMe: isMe, isLocal: isLocal);
      default:
        return Text(message['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : AppTheme.textDark, fontSize: 15));
    }
  }

  void _showFullImage(String url, bool isLocal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullImageScreen(url: url, isLocal: isLocal),
      ),
    );
  }

  Widget _buildVideoPlayer(String url, bool isLocal) {
    return GestureDetector(
      onTap: () => _playVideo(url, isLocal),
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('ویدیو', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playVideo(String url, bool isLocal) {
    debugPrint('🎥 Playing video: $url, isLocal: $isLocal');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url, isLocal: isLocal)),
    );
  }


  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('پاسخ دادن'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('کپی متن'),
              onTap: () {
                Navigator.pop(ctx);
                // Clipboard.setData(ClipboardData(text: message['message'] ?? ''));
              },
            ),
          ],
        ),
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
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // دکمه لغو
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _cancelRecording,
              ),
              // نمایش مدت زمان ضبط
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    const Text('در حال ضبط...', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              // دکمه ارسال
              Container(
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _stopRecording,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // حالت عادی
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _showAttachmentOptions,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: 'پیام خود را بنویسید...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // دکمه ضبط صدا
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.mic, color: Colors.white),
                onPressed: _startRecording,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
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
              title: const Text('تصویر'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text('ویدیو'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
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
