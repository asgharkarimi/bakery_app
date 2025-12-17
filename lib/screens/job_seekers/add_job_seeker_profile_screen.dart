import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/job_seeker.dart';
import '../../models/job_category.dart';
import '../../models/iran_provinces.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_input_formatter.dart';
import '../../utils/number_to_words.dart';
import '../../services/api_service.dart';

class AddJobSeekerProfileScreen extends StatefulWidget {
  final JobSeeker? profileToEdit;
  
  const AddJobSeekerProfileScreen({super.key, this.profileToEdit});

  @override
  State<AddJobSeekerProfileScreen> createState() => _AddJobSeekerProfileScreenState();
}

class _AddJobSeekerProfileScreenState extends State<AddJobSeekerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  bool _isMarried = false;
  bool _isSmoker = false;
  bool _hasAddiction = false;
  List<String> _selectedSkills = [];
  String _salaryWords = '';
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String? _selectedProvince;
  bool _isLoading = false;
  
  bool get _isEditMode => widget.profileToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _populateFields();
    }
  }
  
  void _populateFields() {
    final profile = widget.profileToEdit!;
    final nameParts = profile.name.split(' ');
    _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
    _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    _salaryController.text = _formatNumber(profile.expectedSalary);
    _salaryWords = NumberToWords.convert(_salaryController.text);
    _selectedProvince = profile.location;
    _selectedSkills = List<String>.from(profile.skills);
    _isMarried = profile.isMarried;
    _isSmoker = profile.isSmoker;
    _hasAddiction = profile.hasAddiction;
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انتخاب تصویر')),
        );
      }
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک مهارت انتخاب کنید'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // آپلود عکس پروفایل
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await ApiService.uploadImage(_profileImage!);
      }

      // حذف کاما از حقوق
      final salaryText = _salaryController.text.replaceAll(',', '');
      final salary = int.tryParse(salaryText) ?? 0;

      final data = {
        'name': '${_firstNameController.text} ${_lastNameController.text}',
        'skills': _selectedSkills,
        'expectedSalary': salary,
        'province': _selectedProvince,
        'location': _selectedProvince,
        'isMarried': _isMarried,
        'isSmoker': _isSmoker,
        'hasAddiction': _hasAddiction,
        if (profileImageUrl != null) 'profileImage': profileImageUrl,
      };

      bool success;
      if (_isEditMode) {
        success = await ApiService.updateJobSeeker(widget.profileToEdit!.id, data);
      } else {
        success = await ApiService.createJobSeeker(data);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditMode ? 'پروفایل با موفقیت ویرایش شد' : 'پروفایل با موفقیت ثبت شد'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditMode ? 'خطا در ویرایش پروفایل' : 'خطا در ثبت پروفایل'), backgroundColor: Colors.red),
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
        appBar: AppBar(
          title: Text(_isEditMode ? 'ویرایش پروفایل کارجو' : 'ایجاد پروفایل کارجو'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.background,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: AppTheme.textGrey,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: AppTheme.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'نام',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'نام را وارد کنید' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'نام خانوادگی',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'نام خانوادگی را وارد کنید' : null,
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('متاهل'),
                value: _isMarried,
                onChanged: (value) => setState(() => _isMarried = value),
                activeColor: AppTheme.primaryGreen,
              ),
              SizedBox(height: 16),
              Text('مهارت‌های شغلی:',
                  style: Theme.of(context).textTheme.titleLarge),
              ...JobCategory.getCategories().map(
                (cat) => Row(
                  children: [
                    Checkbox(
                      value: _selectedSkills.contains(cat.title),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedSkills.add(cat.title);
                          } else {
                            _selectedSkills.remove(cat.title);
                          }
                        });
                      },
                      activeColor: AppTheme.primaryGreen,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.title,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: InputDecoration(
                  labelText: 'استان محل زندگی',
                  prefixIcon: Icon(Icons.location_on),
                ),
                isExpanded: true,
                alignment: Alignment.centerRight,
                items: IranProvinces.getProvinces()
                    .map((province) => DropdownMenuItem(
                          value: province,
                          alignment: Alignment.centerRight,
                          child: Text(
                            province,
                            textAlign: TextAlign.right,
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedProvince = value),
                validator: (v) => v == null ? 'استان را انتخاب کنید' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'حقوق هفتگی درخواستی (تومان)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                onChanged: (value) {
                  setState(() {
                    _salaryWords = NumberToWords.convert(value);
                  });
                },
                validator: (v) => v?.isEmpty ?? true ? 'حقوق را وارد کنید' : null,
              ),
              if (_salaryWords.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8, right: 16),
                  child: Text(
                    _salaryWords,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('سیگاری'),
                value: _isSmoker,
                onChanged: (value) => setState(() => _isSmoker = value),
                activeColor: AppTheme.primaryGreen,
              ),
              SwitchListTile(
                title: Text('اعتیاد به مواد مخدر'),
                value: _hasAddiction,
                onChanged: (value) => setState(() => _hasAddiction = value),
                activeColor: AppTheme.primaryGreen,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEditMode ? 'ذخیره تغییرات' : 'ثبت پروفایل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
