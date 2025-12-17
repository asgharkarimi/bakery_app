import 'package:flutter/material.dart';
import '../../models/equipment_ad.dart';
import '../../models/bakery_ad.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../../widgets/add_menu_fab.dart';
import '../equipment/equipment_detail_screen.dart';
import '../bakery/bakery_detail_screen.dart';
import '../map/map_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<EquipmentAd> _equipmentAds = [];
  List<BakeryAd> _bakeryAds = [];
  bool _isLoadingEquipment = true;
  bool _isLoadingBakery = true;
  
  // فیلترها
  String? _selectedProvince;
  BakeryAdType? _selectedType;
  RangeValues _priceRange = const RangeValues(0, 50000000000);
  RangeValues _flourQuotaRange = const RangeValues(0, 1000);
  bool _filtersApplied = false;
  
  final List<String> _provinces = [
    'تهران', 'اصفهان', 'فارس', 'خراسان رضوی', 'آذربایجان شرقی',
    'مازندران', 'خوزستان', 'گیلان', 'کرمان', 'آذربایجان غربی',
    'سیستان و بلوچستان', 'کرمانشاه', 'گلستان', 'هرمزگان', 'لرستان',
    'همدان', 'کردستان', 'مرکزی', 'قزوین', 'اردبیل', 'بوشهر',
    'زنجان', 'قم', 'یزد', 'چهارمحال و بختیاری', 'سمنان',
    'خراسان شمالی', 'خراسان جنوبی', 'کهگیلویه و بویراحمد', 'ایلام', 'البرز',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _loadEquipmentAds();
    _loadBakeryAds();
  }

  Future<void> _loadEquipmentAds() async {
    setState(() => _isLoadingEquipment = true);
    try {
      final ads = await ApiService.getEquipmentAds();
      if (mounted) {
        setState(() {
          _equipmentAds = ads.map((json) => EquipmentAd.fromJson(json)).toList();
          _isLoadingEquipment = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEquipment = false);
    }
  }

  Future<void> _loadBakeryAds() async {
    setState(() => _isLoadingBakery = true);
    try {
      final ads = await ApiService.getBakeryAds(
        type: _selectedType,
        province: _selectedProvince,
        minPrice: _priceRange.start > 0 ? _priceRange.start.toInt() : null,
        maxPrice: _priceRange.end < 50000000000 ? _priceRange.end.toInt() : null,
        minFlourQuota: _flourQuotaRange.start > 0 ? _flourQuotaRange.start.toInt() : null,
        maxFlourQuota: _flourQuotaRange.end < 1000 ? _flourQuotaRange.end.toInt() : null,
      );
      if (mounted) {
        setState(() {
          _bakeryAds = ads;
          _isLoadingBakery = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBakery = false);
    }
  }
  
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
  }
  
  void _showProvinceSelector(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const Text('انتخاب استان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _buildProvinceItem(ctx, setSheetState, null, 'همه استان‌ها'),
                    ..._provinces.map((p) => _buildProvinceItem(ctx, setSheetState, p, p)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProvinceItem(BuildContext ctx, StateSetter setSheetState, String? value, String label) {
    final isSelected = _selectedProvince == value;
    return InkWell(
      onTap: () {
        setSheetState(() => _selectedProvince = value);
        Navigator.pop(ctx);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryGreen : Colors.black87,
                ),
              ),
            ),
            if (isSelected) const SizedBox(width: 12),
            if (isSelected) Icon(Icons.check, color: AppTheme.primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }
  
  void _resetFilters() {
    setState(() {
      _selectedProvince = null;
      _selectedType = null;
      _priceRange = const RangeValues(0, 50000000000);
      _flourQuotaRange = const RangeValues(0, 1000);
      _filtersApplied = false;
    });
    _loadBakeryAds();
  }
  
  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'فیلتر پیشرفته',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedProvince = null;
                          _selectedType = null;
                          _priceRange = const RangeValues(0, 50000000000);
                          _flourQuotaRange = const RangeValues(0, 1000);
                        });
                      },
                      child: Text('پاک کردن', style: TextStyle(color: Colors.red.shade400)),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // نوع آگهی
                      _buildSectionTitle('نوع آگهی', Icons.category),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: [
                          _buildFilterChip(
                            'همه',
                            _selectedType == null,
                            () => setSheetState(() => _selectedType = null),
                            Colors.grey,
                          ),
                          _buildFilterChip(
                            '🏷️ فروش',
                            _selectedType == BakeryAdType.sale,
                            () => setSheetState(() => _selectedType = BakeryAdType.sale),
                            Colors.blue,
                          ),
                          _buildFilterChip(
                            '🔑 رهن و اجاره',
                            _selectedType == BakeryAdType.rent,
                            () => setSheetState(() => _selectedType = BakeryAdType.rent),
                            Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // استان
                      _buildSectionTitle('استان', Icons.location_on),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showProvinceSelector(setSheetState),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: _selectedProvince != null ? AppTheme.primaryGreen : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: _selectedProvince != null ? AppTheme.primaryGreen : Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedProvince ?? 'انتخاب استان',
                                  style: TextStyle(
                                    color: _selectedProvince != null ? Colors.black : Colors.grey,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // محدوده قیمت
                      _buildSectionTitle('محدوده قیمت (تومان)', Icons.attach_money),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatPriceShort(_priceRange.start), style: const TextStyle(fontSize: 12)),
                          Text(_formatPriceShort(_priceRange.end), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 50000000000,
                        divisions: 100,
                        activeColor: AppTheme.primaryGreen,
                        labels: RangeLabels(
                          _formatPriceShort(_priceRange.start),
                          _formatPriceShort(_priceRange.end),
                        ),
                        onChanged: (v) => setSheetState(() => _priceRange = v),
                      ),
                      const SizedBox(height: 24),
                      
                      // سهمیه آرد
                      _buildSectionTitle('سهمیه آرد (کیسه در ماه)', Icons.inventory_2),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_flourQuotaRange.start.toInt()} کیسه', style: const TextStyle(fontSize: 12)),
                          Text('${_flourQuotaRange.end.toInt()} کیسه', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      RangeSlider(
                        values: _flourQuotaRange,
                        min: 0,
                        max: 1000,
                        divisions: 100,
                        activeColor: Colors.deepOrange,
                        labels: RangeLabels(
                          '${_flourQuotaRange.start.toInt()}',
                          '${_flourQuotaRange.end.toInt()}',
                        ),
                        onChanged: (v) => setSheetState(() => _flourQuotaRange = v),
                      ),
                    ],
                  ),
                ),
              ),
              // Apply button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _filtersApplied = true);
                      _loadBakeryAds();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('اعمال فیلتر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  String _formatPriceShort(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)} میلیارد';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(0)} میلیون';
    }
    return '${price.toInt()}';
  }
  
  Widget _buildActiveFiltersBar() {
    final filters = <Widget>[];
    
    if (_selectedType != null) {
      filters.add(_buildActiveFilterChip(
        _selectedType == BakeryAdType.sale ? 'فروش' : 'رهن و اجاره',
        () => setState(() { _selectedType = null; _loadBakeryAds(); }),
      ));
    }
    
    if (_selectedProvince != null) {
      filters.add(_buildActiveFilterChip(
        _selectedProvince!,
        () => setState(() { _selectedProvince = null; _loadBakeryAds(); }),
      ));
    }
    
    if (_priceRange.start > 0 || _priceRange.end < 50000000000) {
      filters.add(_buildActiveFilterChip(
        'قیمت: ${_formatPriceShort(_priceRange.start)} - ${_formatPriceShort(_priceRange.end)}',
        () => setState(() { _priceRange = const RangeValues(0, 50000000000); _loadBakeryAds(); }),
      ));
    }
    
    if (_flourQuotaRange.start > 0 || _flourQuotaRange.end < 1000) {
      filters.add(_buildActiveFilterChip(
        'سهمیه: ${_flourQuotaRange.start.toInt()} - ${_flourQuotaRange.end.toInt()} کیسه',
        () => setState(() { _flourQuotaRange = const RangeValues(0, 1000); _loadBakeryAds(); }),
      ));
    }
    
    if (filters.isEmpty) {
      setState(() => _filtersApplied = false);
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: filters),
            ),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('پاک کردن'),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('بازار'),
          actions: [
            // دکمه فیلتر
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterSheet,
                  tooltip: 'فیلتر',
                ),
                if (_filtersApplied)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MapScreen()),
                );
              },
              tooltip: 'نقشه نانوایی‌ها',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.primaryGreen,
            tabs: [
              Tab(
                icon: Icon(Icons.store),
                text: 'نانوایی',
              ),
              Tab(
                icon: Icon(Icons.precision_manufacturing),
                text: 'دستگاه‌ها',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // نوار فیلترهای فعال
            if (_filtersApplied) _buildActiveFiltersBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBakeryList(),
                  _buildEquipmentList(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: AddMenuFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildEquipmentList() {
    if (_isLoadingEquipment) {
      return Center(child: CircularProgressIndicator());
    }
    if (_equipmentAds.isEmpty) {
      return Center(child: Text('آگهی تجهیزاتی یافت نشد'));
    }
    return RefreshIndicator(
      onRefresh: _loadEquipmentAds,
      child: ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: _equipmentAds.length,
      itemBuilder: (context, index) {
        final ad = _equipmentAds[index];
        return Container(
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EquipmentDetailScreen(ad: ad),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.settings,
                          color: Color(0xFF1976D2),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ad.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppTheme.textGrey,
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppTheme.textGrey,
                      ),
                      SizedBox(width: 4),
                      Text(
                        ad.location,
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'قیمت: ',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          NumberFormatter.formatPrice(ad.price),
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildBakeryList() {
    if (_isLoadingBakery) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bakeryAds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined, size: 80, color: AppTheme.textGrey),
            const SizedBox(height: 16),
            Text('آگهی نانوایی یافت نشد', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBakeryAds,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bakeryAds.length,
        itemBuilder: (context, index) => _buildBakeryCard(_bakeryAds[index]),
      ),
    );
  }

  Widget _buildBakeryCard(BakeryAd ad) {
    final isSale = ad.type == BakeryAdType.sale;
    final color = isSale ? Colors.blue : Colors.purple;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BakeryDetailScreen(ad: ad))),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Image or placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: ad.images.isNotEmpty
                  ? Image.network(
                      ad.images.first.startsWith('http') ? ad.images.first : 'http://10.0.2.2:3000${ad.images.first}',
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(color),
                    )
                  : _buildPlaceholder(color),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge and title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSale ? '🏷️ فروش' : '🔑 رهن و اجاره',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      if (ad.images.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.photo_library, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('${ad.images.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(
                    ad.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ad.location,
                          style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (ad.flourQuota != null && ad.flourQuota! > 0)
                        _buildInfoChip(Icons.inventory_2, '${ad.flourQuota} کیسه آرد', Colors.deepOrange),
                      if (ad.breadPrice != null && ad.breadPrice! > 0)
                        _buildInfoChip(Icons.bakery_dining, NumberFormatter.formatPrice(ad.breadPrice!), Colors.brown),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Price
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isSale
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('قیمت فروش:', style: TextStyle(color: color, fontSize: 14)),
                              Text(
                                NumberFormatter.formatPrice(ad.salePrice ?? 0),
                                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('رهن:', style: TextStyle(color: color, fontSize: 13)),
                                  Text(NumberFormatter.formatPrice(ad.rentDeposit ?? 0), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('اجاره ماهانه:', style: TextStyle(color: color, fontSize: 13)),
                                  Text(NumberFormatter.formatPrice(ad.monthlyRent ?? 0), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 50, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('بدون تصویر', style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
