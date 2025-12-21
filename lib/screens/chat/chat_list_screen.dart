import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/unread_messages_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../auth/login_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoad();
  }

  Future<void> _checkLoginAndLoad() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      setState(() => _isLoggedIn = isLoggedIn);
      if (isLoggedIn) {
        _loadConversations();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await ApiService.getConversations();

      // دکریپت کردن پیام‌ها - بدون await در حلقه برای جلوگیری از هنگ
      for (final conv in conversations) {
        final message = conv['message'];
        final userId = conv['user']?['id'];

        if (message != null && userId != null && message.toString().isNotEmpty) {
          // فقط اگه پیام شبیه رمزشده بود، سعی کن دکریپت کنی
          if (_looksLikeEncrypted(message.toString())) {
            conv['message'] = '🔒 پیام رمزشده';
          }
        }
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
        UnreadMessagesService().loadUnreadCount();
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // چک کردن اینکه پیام شبیه رمزشده هست یا نه
  bool _looksLikeEncrypted(String message) {
    if (message.isEmpty || message.length < 5) return false;
    // اگه پیام حروف فارسی یا عربی داشت، رمزشده نیست
    if (RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(message)) {
      return false;
    }
    // اگه پیام فقط شامل کاراکترهای Base64 باشه، احتمالا رمزشده
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(message);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final time = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(time);
      if (difference.inMinutes < 60) return '${difference.inMinutes} دقیقه پیش';
      if (difference.inHours < 24) return '${difference.inHours} ساعت پیش';
      if (difference.inDays < 7) return '${difference.inDays} روز پیش';
      return '${time.day}/${time.month}';
    } catch (e) {
      return '';
    }
  }

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name[0];
  }

  String _getMessagePreview(Map<String, dynamic> conversation) {
    final type = conversation['messageType'];
    if (type == 'image') return '📷 تصویر';
    if (type == 'video') return '🎥 ویدیو';
    if (type == 'voice') return '🎤 پیام صوتی';

    final message = conversation['message'] ?? '';
    // اگه پیام شبیه رمزشده بود، نشون نده
    if (_looksLikeEncrypted(message)) {
      return '🔒 پیام رمزشده';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(title: const Text('پیام‌ها')),
        body: _isLoading
            ? ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const ChatListShimmer(),
              )
            : !_isLoggedIn
                ? _buildLoginPrompt()
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: _conversations.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) =>
                                _buildConversationItem(_conversations[index]),
                          ),
                  ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'جهت دیدن پیام‌های خود وارد شوید',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'برای مشاهده و ارسال پیام، ابتدا وارد حساب کاربری خود شوید',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  if (result == true) {
                    _checkLoginAndLoad();
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('ورود / ثبت‌نام'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: AppTheme.textGrey),
                const SizedBox(height: 16),
                Text('هنوز پیامی ندارید',
                    style: TextStyle(fontSize: 18, color: AppTheme.textGrey)),
                const SizedBox(height: 8),
                Text('برای شروع گفتگو، از صفحه آگهی پیام بدید',
                    style: TextStyle(fontSize: 14, color: AppTheme.textGrey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final user = conversation['user'] as Map<String, dynamic>?;
    final userPhone = user?['phone']?.toString() ?? '';
    final rawName = user?['name']?.toString();
    // اگه نام داره نشون بده، وگرنه شماره تلفن
    final userName = (rawName != null && rawName.isNotEmpty && rawName != 'کاربر') 
        ? rawName 
        : (userPhone.isNotEmpty ? userPhone : 'کاربر');
    final odUserId = user?['id']?.toString() ?? '0';
    final isOnline = user?['isOnline'] == true;
    final unreadCount = conversation['unreadCount'] ?? 0;
    final createdAt = conversation['createdAt'];
    final profileImage = user?['profileImage']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                recipientId: odUserId,
                recipientName: userName,
                recipientAvatar: _getInitial(userName),
                recipientImage: profileImage,
              ),
            ),
          );
          _loadConversations();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF1976D2),
              backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                  ? NetworkImage('${ApiService.serverUrl}$profileImage')
                  : null,
              child: (profileImage == null || profileImage.isEmpty)
                  ? Text(_getInitial(userName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            if (unreadCount > 0)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text('$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
        title: Text(userName,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
        subtitle: Text(
          _getMessagePreview(conversation),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unreadCount > 0 ? AppTheme.textDark : AppTheme.textGrey,
            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_formatTime(createdAt),
                style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
            if (isOnline) const SizedBox(height: 4),
            if (isOnline)
              Text('آنلاین',
                  style: TextStyle(fontSize: 10, color: Colors.green.shade600)),
          ],
        ),
      ),
    );
  }
}
