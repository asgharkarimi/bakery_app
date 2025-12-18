import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class ViewProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  
  const ViewProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final skills = List<String>.from(user['skills'] ?? []);
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryGreen,
                        AppTheme.primaryGreen.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: user['profileImage'] != null
                              ? NetworkImage('http://10.0.2.2:3000${user['profileImage']}')
                              : null,
                          child: user['profileImage'] == null
                              ? Icon(Icons.person, size: 55, color: AppTheme.primaryGreen)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user['name'] ?? 'کاربر',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                            child: Text(
                              user['bio'],
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        if (user['city'] != null || user['province'] != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                [user['city'], user['province']].where((e) => e != null).join('، '),
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // آمار
                    Row(
                      children: [
                        _buildStatCard(
                          icon: Icons.work_history,
                          value: '${user['experience'] ?? 0}',
                          label: 'سال سابقه',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          icon: Icons.school,
                          value: user['education'] ?? '-',
                          label: 'تحصیلات',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // مهارت‌ها
                    if (skills.isNotEmpty) ...[
                      _buildSectionTitle('مهارت‌ها'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: skills.map((skill) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // اطلاعات تماس
                    _buildSectionTitle('اطلاعات تماس'),
                    _buildInfoCard([
                      if (user['phone'] != null)
                        _buildInfoRow(Icons.phone, 'تلفن', user['phone'], onTap: () {
                          Clipboard.setData(ClipboardData(text: user['phone']));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('شماره کپی شد')),
                          );
                        }),
                      if (user['instagram'] != null && user['instagram'].toString().isNotEmpty)
                        _buildInfoRow(Icons.camera_alt, 'اینستاگرام', '@${user['instagram']}'),
                      if (user['telegram'] != null && user['telegram'].toString().isNotEmpty)
                        _buildInfoRow(Icons.send, 'تلگرام', '@${user['telegram']}'),
                      if (user['website'] != null && user['website'].toString().isNotEmpty)
                        _buildInfoRow(Icons.language, 'وب‌سایت', user['website']),
                    ]),
                    const SizedBox(height: 24),
                    
                    // اطلاعات بیشتر
                    if (user['birthDate'] != null) ...[
                      _buildSectionTitle('اطلاعات بیشتر'),
                      _buildInfoCard([
                        _buildInfoRow(Icons.cake, 'تاریخ تولد', _formatDate(user['birthDate'])),
                        _buildInfoRow(Icons.calendar_today, 'عضویت', _formatDate(user['createdAt'])),
                      ]),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 22),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.copy, size: 16, color: AppTheme.textGrey),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}
