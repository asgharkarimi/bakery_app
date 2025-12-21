import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../models/bakery_ad.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_buttons_style.dart';
import '../../utils/currency_input_formatter.dart';
import '../../utils/number_to_words.dart';
import '../../widgets/image_picker_widget.dart';
import '../map/location_picker_screen.dart';

class AddBakeryAdScreen extends StatefulWidget {
  final BakeryAd? adToEdit;
  
  const AddBakeryAdScreen({super.key, this.adToEdit});

  @override
  State<AddBakeryAdScreen> createState() => _AddBakeryAdScreenState();
}

class _AddBakeryAdScreenState extends State<AddBakeryAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _rentDepositController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _flourQuotaController = TextEditingController();
  final _breadPriceController = TextEditingController();
  final _locationController = TextEditingController();
  BakeryAdType _selectedType = BakeryAdType.sale;
  LatLng? _selectedLatLng;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  String _salePriceWords = '';
  String _rentDepositWords = '';
  String _monthlyRentWords = '';
  String _breadPriceWords = '';
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
    _selectedType = ad.type;
    _selectedAddress = ad.location;
    _locationController.text = ad.location;
    _phoneController.text = ad.phoneNumber;
    
    if (ad.flourQuota != null) {
      _flourQuotaController.text = ad.flourQuota.toString();
    }
    if (ad.breadPrice != null) {
      _breadPriceController.text = _formatNumber(ad.breadPrice!);
      _breadPriceWords = NumberToWords.convert(_breadPriceController.text);
    }
    _images = List.from(ad.images);
    
    if (ad.type == BakeryAdType.sale && ad.salePrice != null) {
      _salePriceController.text = _formatNumber(ad.salePrice!);
      _salePriceWords = NumberToWords.convert(_salePriceController.text);
    } else {
      if (ad.rentDeposit != null) {
        _rentDepositController.text = _formatNumber(ad.rentDeposit!);
        _rentDepositWords = NumberToWords.convert(_rentDepositController.text);
      }
      if (ad.monthlyRent != null) {
        _monthlyRentController.text = _formatNumber(ad.monthlyRent!);
        _monthlyRentWords = NumberToWords.convert(_monthlyRentController.text);
      }
    }
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
    _salePriceController.dispose();
    _rentDepositController.dispose();
    _monthlyRentController.dispose();
    _phoneController.dispose();
    _flourQuotaController.dispose();
    _breadPriceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int _parsePrice(String value) {
    return int.tryParse(value.replaceAll(',', '')) ?? 0;
  }

  // دریافت آدرس از مختصات با Nominatim
  Future<String?> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=fa',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'BakeryApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        // ساخت آدرس خوانا
        final parts = <String>[];
        if (address['state'] != null) parts.add(address['state']);
        if (address['county'] != null) parts.add(address['county']);
        if (address['city'] != null) parts.add(address['city']);
        if (address['suburb'] != null) parts.add(address['suburb']);
        if (address['neighbourhood'] != null) parts.add(address['neighbourhood']);
        if (address['road'] != null) parts.add(address['road']);
        return parts.isNotEmpty ? parts.join('، ') : data['display_name'];
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
    return null;
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final adData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType == BakeryAdType.sale ? 'sale' : 'rent',
        'location': _selectedAddress ?? 'موقعیت انتخاب شده',
        'phoneNumber': _phoneController.text.trim(),
        'images': _images,
        if (_selectedLatLng != null) 'lat': _selectedLatLng!.latitude,
        if (_selectedLatLng != null) 'lng': _selectedLatLng!.longitude,
        if (_flourQuotaController.text.isNotEmpty)
          'flourQuota': int.tryParse(_flourQuotaController.text) ?? 0,
        if (_breadPriceController.text.isNotEmpty)
          'breadPrice': _parsePrice(_breadPriceController.text),
      };

      if (_selectedType == BakeryAdType.sale) {
        adData['salePrice'] = _parsePrice(_salePriceController.text);
      } else {
        adData['rentDeposit'] = _parsePrice(_rentDepositController.text);
        adData['monthlyRent'] = _parsePrice(_monthlyRentController.text);
      }

      bool success;
      if (_isEditMode) {
        success = await ApiService.updateBakeryAd(widget.adToEdit!.id, adData);
      } else {
        success = await ApiService.createBakeryAd(adData);
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
          title: Text(_isEditMode ? 'ویرایش آگهی نانوایی' : 'درج آگهی نانوایی'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Type selector
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نوع آگهی',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      SizedBox(height: 12),
                      SegmentedButton<BakeryAdType>(
                        segments: [
                          ButtonSegment(
                            value: BakeryAdType.sale,
                            label: Text('فروش'),
                            icon: Icon(Icons.sell),
                          ),
                          ButtonSegment(
                            value: BakeryAdType.rent,
                            label: Text('رهن و اجاره'),
                            icon: Icon(Icons.key),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (Set<BakeryAdType> newSelection) {
                          setState(() => _selectedType = newSelection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان آگهی',
                  hintText: 'مثال: فروش نانوایی بربری',
                  prefixIcon: Icon(Icons.title, color: AppTheme.primaryGreen),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'عنوان را وارد کنید' : null,
              ),
              SizedBox(height: 16),

              // Price fields based on type
              if (_selectedType == BakeryAdType.sale) ...[
                TextFormField(
                  controller: _salePriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'قیمت فروش (تومان)',
                    hintText: '0',
                    prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGreen),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _salePriceWords = NumberToWords.convert(value);
                    });
                  },
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'قیمت را وارد کنید' : null,
                ),
                if (_salePriceWords.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8, right: 16, bottom: 8),
                    child: Text(
                      _salePriceWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ] else ...[
                TextFormField(
                  controller: _rentDepositController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'رهن (تومان)',
                    hintText: '0',
                    prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGreen),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _rentDepositWords = NumberToWords.convert(value);
                    });
                  },
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'رهن را وارد کنید' : null,
                ),
                if (_rentDepositWords.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8, right: 16, bottom: 8),
                    child: Text(
                      _rentDepositWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _monthlyRentController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'اجاره ماهانه (تومان)',
                    hintText: '0',
                    prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGreen),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _monthlyRentWords = NumberToWords.convert(value);
                    });
                  },
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'اجاره را وارد کنید' : null,
                ),
                if (_monthlyRentWords.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8, right: 16, bottom: 8),
                    child: Text(
                      _monthlyRentWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
              SizedBox(height: 16),

              // سهمیه آرد
              TextFormField(
                controller: _flourQuotaController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'سهمیه آرد (کیسه در ماه)',
                  hintText: 'مثال: 100',
                  prefixIcon: Icon(Icons.inventory_2, color: AppTheme.primaryGreen),
                ),
              ),
              SizedBox(height: 16),

              // قیمت نان
              TextFormField(
                controller: _breadPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'قیمت نان (تومان)',
                  hintText: 'مثال: 5000',
                  prefixIcon: Icon(Icons.bakery_dining, color: AppTheme.primaryGreen),
                ),
                onChanged: (value) {
                  setState(() {
                    _breadPriceWords = NumberToWords.convert(value);
                  });
                },
              ),
              if (_breadPriceWords.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8, right: 16, bottom: 8),
                  child: Text(
                    _breadPriceWords,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(height: 16),

              // Location picker from map
              TextFormField(
                readOnly: true,
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'محل',
                  hintText: 'انتخاب از روی نقشه',
                  prefixIcon: _isLoadingAddress
                      ? Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(Icons.location_on, color: AppTheme.primaryGreen),
                  suffixIcon: Icon(Icons.map, color: AppTheme.primaryGreen),
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        initialLocation: _selectedLatLng,
                      ),
                    ),
                  );
                  if (result != null && result is LatLng && mounted) {
                    setState(() {
                      _selectedLatLng = result;
                      _isLoadingAddress = true;
                      _locationController.text = 'در حال دریافت آدرس...';
                    });
                    // دریافت آدرس از مختصات
                    final address = await _getAddressFromLatLng(result);
                    if (mounted) {
                      setState(() {
                        _isLoadingAddress = false;
                        _selectedAddress = address ?? 'موقعیت انتخاب شده';
                        _locationController.text = _selectedAddress!;
                      });
                    }
                  }
                },
                validator: (v) => _selectedLatLng == null && _selectedAddress == null ? 'محل را از روی نقشه انتخاب کنید' : null,
              ),
              SizedBox(height: 16),

              // Phone number
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
              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'توضیحات',
                  hintText: 'جزئیات نانوایی را شرح دهید...',
                  prefixIcon: Icon(Icons.description, color: AppTheme.primaryGreen),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'توضیحات را وارد کنید' : null,
              ),
              SizedBox(height: 16),

              // Image picker
              ImagePickerWidget(
                existingImages: _images,
                onImagesChanged: (images) => setState(() => _images = images),
                maxImages: 5,
                title: 'تصاویر نانوایی',
              ),
              
              SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAd,
                  style: AppButtonsStyle.primaryButton(verticalPadding: 18),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditMode ? 'ذخیره تغییرات' : 'ثبت آگهی'),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
