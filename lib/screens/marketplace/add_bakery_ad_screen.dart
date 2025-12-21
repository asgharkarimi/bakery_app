import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../models/bakery_ad.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_input_formatter.dart';
import '../../utils/number_to_words.dart';
import '../map/location_picker_screen.dart';

class AddBakeryAdScreen extends StatefulWidget {
  const AddBakeryAdScreen({super.key});

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
  String _salePriceWords = '';
  String _rentDepositWords = '';
  String _monthlyRentWords = '';
  String _breadPriceWords = '';
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isLoadingAddress = false;

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
      // آپلود عکس‌ها
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        for (var imageFile in _selectedImages) {
          final url = await ApiService.uploadImage(imageFile);
          if (url != null) {
            imageUrls.add(url);
          }
        }
        debugPrint('📸 Uploaded ${imageUrls.length} images: $imageUrls');
      }

      final adData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType == BakeryAdType.sale ? 'sale' : 'rent',
        'location': _selectedAddress ?? 'موقعیت انتخاب شده',
        'phoneNumber': _phoneController.text.trim(),
        'images': imageUrls,
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

      debugPrint('📝 Submitting bakery ad: $adData');
      final success = await ApiService.createBakeryAd(adData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('آگهی شما با موفقیت ثبت شد و پس از تایید مدیر منتشر خواهد شد'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در ثبت آگهی'), backgroundColor: Colors.red),
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
          title: Text('درج آگهی نانوایی'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
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
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'عنوان را وارد کنید' : null,
              ),
              SizedBox(height: 16),
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
                    prefixIcon: Icon(Icons.attach_money),
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
                    padding: EdgeInsets.only(top: 8, right: 16),
                    child: Text(
                      _salePriceWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ),
              ]
              else ...[
                TextFormField(
                  controller: _rentDepositController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'رهن (تومان)',
                    prefixIcon: Icon(Icons.attach_money),
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
                    padding: EdgeInsets.only(top: 8, right: 16),
                    child: Text(
                      _rentDepositWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
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
                    prefixIcon: Icon(Icons.attach_money),
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
                    padding: EdgeInsets.only(top: 8, right: 16),
                    child: Text(
                      _monthlyRentWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
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
                  prefixIcon: Icon(Icons.inventory_2),
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
                  prefixIcon: Icon(Icons.bakery_dining),
                ),
                onChanged: (value) {
                  setState(() {
                    _breadPriceWords = NumberToWords.convert(value);
                  });
                },
              ),
              if (_breadPriceWords.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8, right: 16),
                  child: Text(
                    _breadPriceWords,
                    style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
                  ),
                ),
              SizedBox(height: 16),
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
                validator: (v) => _selectedLatLng == null ? 'محل را از روی نقشه انتخاب کنید' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'شماره تماس',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'شماره تماس را وارد کنید' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'توضیحات',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'توضیحات را وارد کنید' : null,
              ),
              SizedBox(height: 16),
              
              // بخش عکس‌ها
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textGrey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: AppTheme.primaryGreen),
                        SizedBox(width: 8),
                        Text(
                          'تصاویر نانوایی',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _selectedImages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _selectedImages.length) {
                          return GestureDetector(
                            onTap: () async {
                              try {
                                final XFile? image = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                
                                if (image != null && mounted) {
                                  setState(() {
                                    _selectedImages.add(File(image.path));
                                  });
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('عکس اضافه شد'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('خطا در انتخاب عکس'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryGreen,
                                  style: BorderStyle.solid,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    color: AppTheme.primaryGreen,
                                    size: 32,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'افزودن',
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(_selectedImages[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    
                    if (_selectedImages.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'حداقل یک عکس از نانوایی اضافه کنید',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAd,
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('ثبت آگهی'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
