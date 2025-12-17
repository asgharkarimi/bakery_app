import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/equipment_ad.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../../services/bookmark_service.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import '../map/map_screen.dart';
import 'add_equipment_ad_screen.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final EquipmentAd ad;

  const EquipmentDetailScreen({super.key, required this.ad});

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  bool _isBookmarked = false;
  bool _isOwner = false;
  late EquipmentAd _ad;

  @override
  void initState() {
    super.initState();
    _ad = widget.ad;
    _checkBookmark();
    _checkOwnership();
  }
  
  Future<void> _checkOwnership() async {
    final userId = await ApiService.getCurrentUserId();
    if (mounted && userId != null) {
      setState(() => _isOwner = _ad.userId == userId);
    }
  }

  Future<void> _checkBookmark() async {
    final isBookmarked = await BookmarkService.isBookmarked(widget.ad.id, 'equipment');
    setState(() {
      _isBookmarked = isBookmarked;
    });
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await BookmarkService.removeBookmark(widget.ad.id, 'equipment');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('از نشانک‌ها حذف شد'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      await BookmarkService.addBookmark(widget.ad.id, 'equipment');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('به نشانک‌ها اضافه شد'),
          backgroundColor: Color(0xFF1976D2),
        ),
      );
    }
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('جزئیات آگهی'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_isOwner)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEquipmentAdScreen(adToEdit: _ad),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.amber : null,
              ),
              onPressed: _toggleBookmark,
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ad.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    
                    Text(
                      _ad.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                        height: 1.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),
                    
                    _buildInfoRow(
                      icon: Icons.location_on,
                      label: 'محل',
                      value: _ad.location,
                      iconColor: Color(0xFF1976D2),
                    ),
                    SizedBox(height: 20),
                    
                    _buildInfoRow(
                      icon: Icons.attach_money,
                      label: 'قیمت',
                      value: NumberFormatter.formatPrice(_ad.price),
                      iconColor: Color(0xFF1976D2),
                    ),
                    SizedBox(height: 20),
                    
                    _buildInfoRow(
                      icon: Icons.phone,
                      label: 'تماس',
                      value: _ad.phoneNumber,
                      iconColor: Color(0xFF1976D2),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MapScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, color: AppTheme.white),
                        SizedBox(width: 8),
                        Text(
                          'نمایش روی نقشه',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _ad.phoneNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('شماره تماس کپی شد'),
                          backgroundColor: Color(0xFF1976D2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, color: AppTheme.white),
                        SizedBox(width: 8),
                        Text(
                          'تماس با آگهی دهنده',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            recipientId: '1',
                            recipientName: 'فروشنده',
                            recipientAvatar: 'ف',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppTheme.white),
                        SizedBox(width: 8),
                        Text(
                          'ارسال پیام به آگهی دهنده',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
