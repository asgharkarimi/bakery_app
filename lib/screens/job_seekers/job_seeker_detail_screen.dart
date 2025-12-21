import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/job_seeker.dart';
import '../../models/review.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../../utils/time_ago.dart';
import '../../widgets/rating_badge.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import '../reviews/reviews_screen.dart';
import 'add_job_seeker_profile_screen.dart';

class JobSeekerDetailScreen extends StatefulWidget {
  final JobSeeker seeker;

  const JobSeekerDetailScreen({super.key, required this.seeker});

  @override
  State<JobSeekerDetailScreen> createState() => _JobSeekerDetailScreenState();
}

class _JobSeekerDetailScreenState extends State<JobSeekerDetailScreen> {
  bool _isOwner = false;
  bool _isLoggedIn = false;
  late JobSeeker _seeker;

  @override
  void initState() {
    super.initState();
    _seeker = widget.seeker;
    _checkOwnership();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      setState(() => _isLoggedIn = loggedIn);
    }
  }

  Future<void> _refreshData() async {
    final refreshed = await ApiService.getJobSeekerById(_seeker.id);
    if (refreshed != null && mounted) {
      setState(() => _seeker = refreshed);
    }
  }

  Future<void> _checkOwnership() async {
    final userId = await ApiService.getCurrentUserId();
    if (mounted && userId != null) {
      setState(() => _isOwner = _seeker.userId == userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
            // هدر با گرادیانت
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: AppTheme.primaryGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
              ),
              actions: [
                if (_isOwner)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddJobSeekerProfileScreen(profileToEdit: _seeker)),
                      );
                      if (result == true && mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),

            // محتوا
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // مهارت‌ها
                        _buildSkillsSection(),
                        const SizedBox(height: 16),
                        // اطلاعات شخصی
                        _buildInfoCard(
                          title: 'اطلاعات شخصی',
                          icon: Icons.person_outline,
                          color: Colors.blue,
                          children: [
                            _buildInfoRow(Icons.family_restroom, 'وضعیت تاهل', _seeker.isMarried ? 'متاهل' : 'مجرد', Colors.pink),
                            _buildInfoRow(Icons.location_on, 'محل سکونت', _seeker.location, Colors.red),
                            if (_seeker.age != null)
                              _buildInfoRow(Icons.cake, 'سن', '${_seeker.age} سال', Colors.orange),
                            _buildInfoRow(Icons.work_history, 'سابقه کار', '${_seeker.experience} سال', Colors.teal),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // اطلاعات مالی
                        _buildSalaryCard(),
                        const SizedBox(height: 16),
                        // سایر اطلاعات
                        _buildInfoCard(
                          title: 'سایر اطلاعات',
                          icon: Icons.info_outline,
                          color: Colors.purple,
                          children: [
                            _buildStatusRow(Icons.smoking_rooms, 'سیگاری', _seeker.isSmoker),
                            _buildStatusRow(Icons.warning_amber, 'اعتیاد', _seeker.hasAddiction),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // دکمه‌ها
                        _buildActionButtons(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
        // دکمه تماس ثابت
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // آواتار با حاشیه
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white,
                backgroundImage: _seeker.profileImage != null
                    ? NetworkImage('${ApiService.serverUrl}${_seeker.profileImage}')
                    : null,
                child: _seeker.profileImage == null
                    ? Text(
                        _seeker.firstName[0],
                        style: TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // اسم
            Text(
              _seeker.fullName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // زمان و امتیاز
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        TimeAgo.format(_seeker.createdAt),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RatingBadge(
                  targetId: _seeker.id,
                  targetType: ReviewTargetType.jobSeeker,
                  targetName: _seeker.fullName,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSkillsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'مهارت‌های شغلی',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _seeker.skills.map((skill) => _buildSkillChip(skill)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            skill,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (status ? Colors.red : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: status ? Colors.red : Colors.green, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (status ? Colors.red : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status ? 'بله' : 'خیر',
              style: TextStyle(
                color: status ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSalaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حقوق هفتگی درخواستی',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  NumberFormatter.formatPrice(_seeker.expectedSalary),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.rate_review_outlined,
            label: 'نظرات',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewsScreen(
                    targetId: _seeker.id,
                    targetType: ReviewTargetType.jobSeeker,
                    targetName: _seeker.fullName,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.share_outlined,
            label: 'اشتراک',
            color: Colors.orange,
            onTap: () => _shareSeeker(),
          ),
        ),
      ],
    );
  }

  void _shareSeeker() {
    final shareText = '''
👤 کارجوی نانوایی

📌 ${_seeker.fullName}
🎂 سن: ${_seeker.age} سال
💼 سابقه کار: ${_seeker.experience} سال
📍 محل سکونت: ${_seeker.location}
💰 حقوق درخواستی: ${NumberFormatter.formatPrice(_seeker.expectedSalary)}
🔧 مهارت‌ها: ${_seeker.skills.join('، ')}
📞 تماس: ${_seeker.phoneNumber}

📱 اپلیکیشن کاریابی نانوایی
''';
    Share.share(shareText.trim(), subject: _seeker.fullName);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // دکمه پیام
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!_isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('برای ارسال پیام ابتدا وارد شوید')),
                    );
                    return;
                  }
                  final recipientId = _seeker.userId?.toString() ?? '';
                  debugPrint('🔍 JobSeeker userId: $recipientId, seeker.id: ${_seeker.id}');
                  if (recipientId.isEmpty || recipientId == '0' || recipientId == 'null') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('امکان ارسال پیام وجود ندارد'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        recipientId: recipientId,
                        recipientName: _seeker.fullName,
                        recipientAvatar: _seeker.firstName[0],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text(
                  'ارسال پیام',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // دکمه تماس - فقط برای کاربران لاگین شده
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _isLoggedIn ? AppTheme.primaryGreen : Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: () {
                  if (!_isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('برای مشاهده شماره تماس ابتدا وارد شوید')),
                    );
                    return;
                  }
                  if (_seeker.phoneNumber != null) {
                    Clipboard.setData(ClipboardData(text: _seeker.phoneNumber!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('شماره ${_seeker.phoneNumber} کپی شد'),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  }
                },
                icon: Icon(Icons.phone, color: _isLoggedIn ? AppTheme.primaryGreen : Colors.grey),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
