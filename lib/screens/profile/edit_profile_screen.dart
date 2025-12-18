import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/jalali_date.dart';
import '../../widgets/jalali_date_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const EditProfileScreen({super.key, this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _educationController = TextEditingController();
  final _instagramController = TextEditingController();
  final _telegramController = TextEditingController();
  final _websiteController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  
  String? _selectedProvince;
  int _experience = 0;
  List<String> _skills = [];
  DateTime? _birthDate;
  
  final _skillController = TextEditingController();

  final List<String> _provinces = [
    'تهران', 'اصفهان', 'فارس', 'خراسان رضوی', 'آذربایجان شرقی',
    'مازندران', 'خوزستان', 'گیلان', 'کرمان', 'آذربایجان غربی',
    'سیستان و بلوچستان', 'کرمانشاه', 'گلستان', 'هرمزگان', 'لرستان',
    'همدان', 'کردستان', 'مرکزی', 'قزوین', 'اردبیل', 'بوشهر',
    'زنجان', 'قم', 'یزد', 'چهارمحال و بختیاری', 'البرز',
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
      _bioController.text = user['bio'] ?? '';
      _cityController.text = user['city'] ?? '';
      _educationController.text = user['education'] ?? '';
      _instagramController.text = user['instagram'] ?? '';
      _telegramController.text = user['telegram'] ?? '';
      _websiteController.text = user['website'] ?? '';
      _currentImageUrl = user['profileImage'];
      _selectedProvince = user['province'];
      _experience = user['experience'] ?? 0;
      _skills = List<String>.from(user['skills'] ?? []);
      if (user['birthDate'] != null) {
        _birthDate = DateTime.tryParse(user['birthDate']);
      }
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _educationController.dispose();
    _instagramController.dispose();
    _telegramController.dispose();
    _websiteController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  Future<void> _selectBirthDate() async {
    final date = await showJalaliDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _birthDate = date);
    }
  }

  String _formatJalaliDate(DateTime date) {
    final jalali = JalaliDate.fromDateTime(date);
    return '${jalali.day} ${jalali.monthName} ${jalali.year}';
  }

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() => _skills.remove(skill));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;
      if (_profileImage != null) {
        imageUrl = await ApiService.uploadImage(_profileImage!);
        if (imageUrl == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('خطا در آپلود عکس'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }

      final success = await ApiService.updateProfile(
        name: _nameController.text.trim(),
        profileImage: imageUrl,
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
        province: _selectedProvince,
        birthDate: _birthDate?.toIso8601String().split('T').first,
        skills: _skills,
        experience: _experience,
        education: _educationController.text.trim(),
        instagram: _instagramController.text.trim(),
        telegram: _telegramController.text.trim(),
        website: _websiteController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
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
        appBar: AppBar(title: const Text('ویرایش پروفایل')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // عکس پروفایل
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.background,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (_currentImageUrl != null
                              ? NetworkImage('http://10.0.2.2:3000$_currentImageUrl')
                              : null) as ImageProvider?,
                      child: _profileImage == null && _currentImageUrl == null
                          ? Icon(Icons.person, size: 60, color: AppTheme.textGrey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // اطلاعات اصلی
              _buildSectionTitle('اطلاعات اصلی'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'نام و نام خانوادگی',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'نام را وارد کنید' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'درباره من',
                  prefixIcon: Icon(Icons.info_outline),
                  hintText: 'چند خط درباره خودتان بنویسید...',
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              
              // تاریخ تولد
              InkWell(
                onTap: _selectBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاریخ تولد',
                    prefixIcon: Icon(Icons.cake),
                  ),
                  child: Text(
                    _birthDate != null
                        ? _formatJalaliDate(_birthDate!)
                        : 'انتخاب کنید',
                    style: TextStyle(
                      color: _birthDate != null ? AppTheme.textDark : AppTheme.textGrey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // موقعیت مکانی
              _buildSectionTitle('موقعیت مکانی'),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'استان',
                  prefixIcon: Icon(Icons.map),
                ),
                items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _selectedProvince = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'شهر',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 24),
              
              // سابقه کار و تحصیلات
              _buildSectionTitle('سابقه کار و تحصیلات'),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'سابقه کار (سال)',
                        prefixIcon: Icon(Icons.work_history),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _experience > 0
                                ? () => setState(() => _experience--)
                                : null,
                          ),
                          Text(
                            '$_experience',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _experience++),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _educationController,
                decoration: const InputDecoration(
                  labelText: 'تحصیلات',
                  prefixIcon: Icon(Icons.school),
                  hintText: 'مثال: دیپلم، کارشناسی...',
                ),
              ),
              const SizedBox(height: 24),
              
              // مهارت‌ها
              _buildSectionTitle('مهارت‌ها'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skillController,
                      decoration: const InputDecoration(
                        labelText: 'افزودن مهارت',
                        prefixIcon: Icon(Icons.star),
                        hintText: 'مثال: نان فانتزی',
                      ),
                      onFieldSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addSkill,
                    icon: Icon(Icons.add_circle, color: AppTheme.primaryGreen, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((skill) => Chip(
                  label: Text(skill),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeSkill(skill),
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: AppTheme.primaryGreen),
                )).toList(),
              ),
              const SizedBox(height: 24),
              
              // شبکه‌های اجتماعی
              _buildSectionTitle('شبکه‌های اجتماعی'),
              TextFormField(
                controller: _instagramController,
                decoration: const InputDecoration(
                  labelText: 'اینستاگرام',
                  prefixIcon: Icon(Icons.camera_alt),
                  hintText: 'نام کاربری بدون @',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telegramController,
                decoration: const InputDecoration(
                  labelText: 'تلگرام',
                  prefixIcon: Icon(Icons.send),
                  hintText: 'نام کاربری بدون @',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'وب‌سایت',
                  prefixIcon: Icon(Icons.language),
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 32),
              
              // دکمه ذخیره
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('ذخیره تغییرات'),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
}
