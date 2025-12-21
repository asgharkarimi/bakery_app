import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/equipment_ad.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_input_formatter.dart';
import '../../utils/number_to_words.dart';
import '../../widgets/image_picker_widget.dart';

class AddEquipmentAdScreen extends StatefulWidget {
  final EquipmentAd? adToEdit;
  
  const AddEquipmentAdScreen({super.key, this.adToEdit});

  @override
  State<AddEquipmentAdScreen> createState() => _AddEquipmentAdScreenState();
}

class _AddEquipmentAdScreenState extends State<AddEquipmentAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  String _condition = 'used';
  String _priceWords = '';
  bool _isLoading = false;
  List<String> _images = [];
  
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
    _descriptionController.text = ad.description;
    _priceController.text = _formatNumber(ad.price);
    _priceWords = NumberToWords.convert(_priceController.text);
    _locationController.text = ad.location;
    _phoneController.text = ad.phoneNumber;
    _condition = ad.condition;
    _images = List.from(ad.images);
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
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  int _parsePrice(String value) {
    return int.tryParse(value.replaceAll(',', '')) ?? 0;
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final adData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _parsePrice(_priceController.text),
        'location': _locationController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'condition': _condition,
        'images': _images,
      };

      bool success;
      if (_isEditMode) {
        success = await ApiService.updateEquipmentAd(widget.adToEdit!.id, adData);
      } else {
        success = await ApiService.createEquipmentAd(adData);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode ? 'آگهی با موفقیت ویرایش شد' : 'آگهی شما با موفقیت ثبت شد و پس از تایید مدیر منتشر خواهد شد'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode ? 'خطا در ویرایش آگهی' : 'خطا در ثبت آگهی'),
              backgroundColor: Colors.red,
            ),
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
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(_isEditMode ? 'ویرایش آگهی دستگاه' : 'درج آگهی دستگاه'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // وضعیت دستگاه
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وضعیت دستگاه',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'new', label: Text('نو'), icon: Icon(Icons.fiber_new)),
                          ButtonSegment(value: 'used', label: Text('کارکرده'), icon: Icon(Icons.history)),
                        ],
                        selected: {_condition},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() => _condition = newSelection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان',
                  hintText: 'مثال: دستگاه فر نانوایی',
                  prefixIcon: Icon(Icons.title, color: AppTheme.primaryGreen),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'عنوان را وارد کنید' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'قیمت (تومان)',
                  prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGreen),
                ),
                onChanged: (value) {
                  setState(() {
                    _priceWords = NumberToWords.convert(value);
                  });
                },
                validator: (v) => v?.isEmpty ?? true ? 'قیمت را وارد کنید' : null,
              ),
              if (_priceWords.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: Text(
                    _priceWords,
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'محل',
                  hintText: 'مثال: تهران، خیابان ولیعصر',
                  prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryGreen),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'محل را وارد کنید' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'شماره تماس',
                  hintText: '09123456789',
                  prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGreen),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'شماره تماس را وارد کنید';
                  if (v!.length != 11) return 'شماره تماس باید 11 رقم باشد';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'توضیحات',
                  hintText: 'جزئیات دستگاه را شرح دهید...',
                  prefixIcon: Icon(Icons.description, color: AppTheme.primaryGreen),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v?.isEmpty ?? true ? 'توضیحات را وارد کنید' : null,
              ),
              const SizedBox(height: 16),
              
              // Image picker
              ImagePickerWidget(
                existingImages: _images,
                onImagesChanged: (images) => setState(() => _images = images),
                maxImages: 5,
                title: 'تصاویر دستگاه',
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isEditMode ? 'ذخیره تغییرات' : 'ثبت آگهی',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
