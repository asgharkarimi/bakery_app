import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/user_cache_service.dart';
import '../../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const EditProfileScreen({super.key, this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  String? _currentImageUrl;
  bool _isLoading = false;

  String? _selectedProvince;
  int _experience = 0;

  final List<String> _provinces = [
    'تهران', 'البرز', 'اصفهان', 'فارس', 'خراسان رضوی', 'آذربایجان شرقی',
    'مازندران', 'خوزستان', 'گیلان', 'کرمان', 'آذربایجان غربی',
    'سیستان و بلوچستان', 'کرمانشاه', 'گلستان', 'هرمزگان', 'لرستان',
    'همدان', 'کردستان', 'مرکزی', 'قزوین', 'اردبیل', 'بوشهر',
    'زنجان', 'قم', 'یزد', 'چهارمحال و بختیاری',
    'ایلام', 'کهگیلویه و بویراحمد', 'سمنان', 'خراسان شمالی', 'خراسان جنوبی'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = widget.user;
    if (user != null) {
      _nameController.text = user['name'] ?? '';
      _currentImageUrl = user['profileImage'];
      _selectedProvince = user['province'];
      _experience = user['experience'] ?? 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.blue.shade600),
                ),
                title: const Text('انتخاب از گالری'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    setState(() => _profileImage = File(image.path));
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.green.shade600),
                ),
                title: const Text('گرفتن عکس'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    setState(() => _profileImage = File(image.path));
                  }
                },
              ),
              if (_profileImage != null || _currentImageUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete, color: Colors.red.shade600),
                  ),
                  title: const Text('حذف عکس'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _profileImage = null;
                      _currentImageUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;
      if (_profileImage != null) {
        imageUrl = await ApiService.uploadImage(_profileImage!);
        if (imageUrl == null && mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در آپلود عکس'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      final success = await ApiService.updateProfile(
        name: _nameController.text.trim(),
        profileImage: imageUrl,
        province: _selectedProvince,
        experience: _experience,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          UserCacheService.markDirty();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('پروفایل بروزرسانی شد'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در بروزرسانی'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('ویرایش پروفایل'),
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // هدر با عکس پروفایل
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.white,
                                backgroundImage: _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : (_currentImageUrl != null
                                        ? NetworkImage('${ApiService.serverUrl}$_currentImageUrl')
                                        : null) as ImageProvider?,
                                child: _profileImage == null && _currentImageUrl == null
                                    ? Icon(Icons.person, size: 55, color: AppTheme.textGrey)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.camera_alt, color: AppTheme.primaryGreen, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'برای تغییر عکس ضربه بزنید',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // فرم
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // کارت نام
                      _buildCard(
                        icon: Icons.person_outline,
                        title: 'نام و نام خانوادگی',
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'نام خود را وارد کنید',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 16),
                          validator: (v) => v?.isEmpty ?? true ? 'نام را وارد کنید' : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // کارت استان
                      _buildCard(
                        icon: Icons.location_on_outlined,
                        title: 'استان محل زندگی',
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedProvince,
                            isExpanded: true,
                            hint: const Text('انتخاب کنید'),
                            items: _provinces
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedProvince = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // کارت سابقه کار
                      _buildCard(
                        icon: Icons.work_outline,
                        title: 'سابقه کار',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildExperienceButton(
                              icon: Icons.remove,
                              onTap: _experience > 0 ? () => setState(() => _experience--) : null,
                            ),
                            Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Text(
                                    '$_experience',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    'سال',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildExperienceButton(
                              icon: Icons.add,
                              onTap: () => setState(() => _experience++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // دکمه ذخیره
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline),
                                    SizedBox(width: 8),
                                    Text('ذخیره تغییرات', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildExperienceButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.primaryGreen : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.white : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
