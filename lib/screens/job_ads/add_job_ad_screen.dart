import 'package:flutter/material.dart';
import '../../models/job_ad.dart';
import '../../models/job_category.dart';
import '../../models/iran_provinces.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_input_formatter.dart';
import '../../utils/number_to_words.dart';
import '../../services/api_service.dart';


class AddJobAdScreen extends StatefulWidget {
  final JobAd? adToEdit;
  
  const AddJobAdScreen({super.key, this.adToEdit});

  @override
  State<AddJobAdScreen> createState() => _AddJobAdScreenState();
}

class _AddJobAdScreenState extends State<AddJobAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dailyBagsController = TextEditingController();
  final _salaryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedProvince;
  String _salaryWords = '';
  bool _isLoading = false;
  bool _hasInsurance = false;
  bool _hasAccommodation = false;
  bool _hasVacation = false;
  final _vacationDaysController = TextEditingController();
  
  bool get _isEditMode => widget.adToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _populateFields();
    }
  }
  
  void _populateFields() {
    final ad = widget.adToEdit!;
    _titleController.text = ad.title;
    _dailyBagsController.text = ad.dailyBags.toString();
    _salaryController.text = _formatNumber(ad.salary);
    _salaryWords = NumberToWords.convert(_salaryController.text);
    _phoneController.text = ad.phoneNumber;
    _descriptionController.text = ad.description;
    _selectedCategory = ad.category;
    _selectedProvince = ad.location;
    _hasInsurance = ad.hasInsurance;
    _hasAccommodation = ad.hasAccommodation;
    _hasVacation = ad.hasVacation;
    _vacationDaysController.text = ad.vacationDays.toString();
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dailyBagsController.dispose();
    _salaryController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _vacationDaysController.dispose();
    super.dispose();
  }

  // تبدیل اعداد فارسی به انگلیسی
  String _convertPersianToEnglish(String input) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < persian.length; i++) {
      result = result.replaceAll(persian[i], english[i]);
    }
    return result;
  }

  int _parseNumber(String value) {
    final converted = _convertPersianToEnglish(value);
    return int.tryParse(converted.replaceAll(',', '')) ?? 0;
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final adData = {
        'title': _titleController.text,
        'category': _selectedCategory,
        'dailyBags': _parseNumber(_dailyBagsController.text),
        'salary': _parseNumber(_salaryController.text),
        'location': _selectedProvince,
        'phoneNumber': _convertPersianToEnglish(_phoneController.text),
        'description': _descriptionController.text,
        'images': [],
        'hasInsurance': _hasInsurance,
        'hasAccommodation': _hasAccommodation,
        'hasVacation': _hasVacation,
        'vacationDays': _hasVacation ? _parseNumber(_vacationDaysController.text) : 0,
      };

      bool success;
      if (_isEditMode) {
        success = await ApiService.updateJobAd(widget.adToEdit!.id, adData);
      } else {
        success = await ApiService.createJobAd(adData);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'آگهی با موفقیت ویرایش شد' : 'آگهی شما با موفقیت ثبت شد و پس از تایید مدیر منتشر خواهد شد'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'خطا در ویرایش آگهی' : 'خطا در ثبت آگهی. لطفاً دوباره تلاش کنید'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'ویرایش آگهی' : 'درج آگهی نیازمند همکار'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان آگهی',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'عنوان را وارد کنید' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'تخصص مورد نیاز',
                  prefixIcon: Icon(Icons.category),
                ),
                isExpanded: true,
                alignment: Alignment.centerRight,
                items: JobCategory.getCategories()
                    .map((cat) => DropdownMenuItem(
                          value: cat.title,
                          alignment: Alignment.centerRight,
                          child: Text(
                            cat.title,
                            textAlign: TextAlign.right,
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (v) => v == null ? 'تخصص را انتخاب کنید' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyBagsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'تعداد کارکرد روزانه (کیسه)',
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'تعداد کارکرد روزانه را وارد کنید' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'حقوق هفتگی (تومان)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                onChanged: (value) {
                  setState(() {
                    _salaryWords = NumberToWords.convert(value);
                  });
                },
                validator: (v) => v?.isEmpty ?? true ? 'حقوق هفتگی را وارد کنید' : null,
              ),
              if (_salaryWords.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: Text(
                    _salaryWords,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'استان محل کار',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'شماره تماس',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'شماره تماس را وارد کنید';
                  if (v!.length != 11) return 'شماره تماس باید ۱۱ رقم باشد';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // امکانات
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('امکانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('بیمه'),
                        subtitle: const Text('آیا بیمه تامین اجتماعی دارد؟'),
                        value: _hasInsurance,
                        onChanged: (v) => setState(() => _hasInsurance = v),
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('محل خواب'),
                        subtitle: const Text('آیا محل اقامت دارد؟'),
                        value: _hasAccommodation,
                        onChanged: (v) => setState(() => _hasAccommodation = v),
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('تعطیلات'),
                        subtitle: const Text('آیا روز تعطیل دارد؟'),
                        value: _hasVacation,
                        onChanged: (v) => setState(() => _hasVacation = v),
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_hasVacation) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _vacationDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'تعداد روز تعطیل در ماه',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'توضیحات',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAd,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'ذخیره تغییرات' : 'ثبت آگهی',
                          style: const TextStyle(fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
