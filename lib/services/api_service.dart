import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_ad.dart';
import '../models/job_seeker.dart';
import '../models/bakery_ad.dart';
import '../models/equipment_ad.dart';
import 'media_compressor.dart';
import 'cache_service.dart';
import 'encryption_service.dart';

class ApiService {
  // برای تست روی امولاتور اندروید از 10.0.2.2 استفاده کن
  // برای دستگاه واقعی از IP کامپیوترت استفاده کن
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const Duration _timeout = Duration(seconds: 5);
  
  static String? _token;
  static int? _currentUserId;
  
  // Callback برای نمایش پیام آفلاین
  static Function(String)? onServerUnavailable;

  // ==================== Auth ====================
  
  static Future<void> _loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ارسال کد تایید
  static Future<Map<String, dynamic>> sendVerificationCode(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'خطا در اتصال به سرور'};
    }
  }

  // تایید کد و ورود
  static Future<Map<String, dynamic>> verifyCode(String phone, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['token'] != null) {
        await _saveToken(data['token']);
        // ذخیره userId
        if (data['user'] != null && data['user']['id'] != null) {
          _currentUserId = data['user']['id'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', _currentUserId!);
          // تنظیم userId برای رمزنگاری
          EncryptionService.setMyUserId(_currentUserId!);
        }
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'خطا در اتصال به سرور'};
    }
  }
  
  // دریافت userId کاربر فعلی
  static Future<int?> getCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId;
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    // تنظیم userId برای رمزنگاری
    if (_currentUserId != null) {
      EncryptionService.setMyUserId(_currentUserId!);
    }
    return _currentUserId;
  }

  // دریافت اطلاعات کاربر
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    await _loadToken();
    if (_token == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ویرایش پروفایل
  static Future<bool> updateProfile({String? name, String? profileImage}) async {
    await _loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (profileImage != null) 'profileImage': profileImage,
        }),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Job Ads ====================
  
  static Future<List<JobAd>> getJobAds({
    String? category,
    String? location,
    int? minSalary,
    int? maxSalary,
    String? search,
    int page = 1,
    bool useCache = true,
  }) async {
    // اگه صفحه اول و بدون فیلتر بود، از کش استفاده کن
    final canUseCache = useCache && page == 1 && category == null && location == null && search == null;
    
    try {
      final params = <String, String>{
        'page': page.toString(),
        if (category != null) 'category': category,
        if (location != null) 'location': location,
        if (minSalary != null) 'minSalary': minSalary.toString(),
        if (maxSalary != null) 'maxSalary': maxSalary.toString(),
        if (search != null) 'search': search,
      };
      
      final uri = Uri.parse('$baseUrl/job-ads').replace(queryParameters: params);
      final response = await http.get(uri).timeout(_timeout);
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final list = data['data'] as List;
        // کش کردن نتایج
        if (canUseCache) {
          await CacheService.cacheJobAds(List<Map<String, dynamic>>.from(list));
        }
        return list.map((json) => JobAd.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching job ads: $e');
      // در صورت خطا، از کش استفاده کن
      if (canUseCache) {
        final cached = await CacheService.getJobAds();
        if (cached != null) {
          debugPrint('📦 Using cached job ads');
          onServerUnavailable?.call('سرور در دسترس نیست - نمایش از حافظه');
          return cached.map((json) => JobAd.fromJson(json)).toList();
        }
      }
      onServerUnavailable?.call('سرور در دسترس نیست');
      return [];
    }
  }

  static Future<JobAd?> getJobAdById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/job-ads/$id'));
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return JobAd.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> createJobAd(Map<String, dynamic> adData) async {
    await _loadToken();
    try {
      print('📝 ارسال آگهی: $adData');
      print('🔑 توکن: $_token');
      final response = await http.post(
        Uri.parse('$baseUrl/job-ads'),
        headers: _headers,
        body: jsonEncode(adData),
      );
      print('📥 پاسخ: ${response.body}');
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('❌ خطا در ارسال آگهی: $e');
      return false;
    }
  }

  static Future<List<JobAd>> getMyJobAds() async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/job-ads/my/list'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return (data['data'] as List).map((json) => JobAd.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateJobAd(String id, Map<String, dynamic> adData) async {
    await _loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/job-ads/$id'),
        headers: _headers,
        body: jsonEncode(adData),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Error updating job ad: $e');
      return false;
    }
  }

  // ==================== Job Seekers ====================
  
  static Future<List<JobSeeker>> getJobSeekers({
    String? location,
    int? maxSalary,
    String? search,
    int page = 1,
    bool useCache = true,
  }) async {
    final canUseCache = useCache && page == 1 && location == null && search == null;
    
    try {
      final params = <String, String>{
        'page': page.toString(),
        if (location != null) 'location': location,
        if (maxSalary != null) 'maxSalary': maxSalary.toString(),
        if (search != null) 'search': search,
      };
      
      final uri = Uri.parse('$baseUrl/job-seekers').replace(queryParameters: params);
      final response = await http.get(uri).timeout(_timeout);
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final list = data['data'] as List;
        if (canUseCache) {
          await CacheService.cacheJobSeekers(List<Map<String, dynamic>>.from(list));
        }
        return list.map((json) => JobSeeker.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (canUseCache) {
        final cached = await CacheService.getJobSeekers();
        if (cached != null) {
          debugPrint('📦 Using cached job seekers');
          onServerUnavailable?.call('سرور در دسترس نیست - نمایش از حافظه');
          return cached.map((json) => JobSeeker.fromJson(json)).toList();
        }
      }
      onServerUnavailable?.call('سرور در دسترس نیست');
      return [];
    }
  }

  static Future<JobSeeker?> getJobSeekerById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/job-seekers/$id'));
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return JobSeeker.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> createJobSeeker(Map<String, dynamic> seekerData) async {
    await _loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/job-seekers'),
        headers: _headers,
        body: jsonEncode(seekerData),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<JobSeeker>> getMyJobSeekers() async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/job-seekers/my/list'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return (data['data'] as List).map((json) => JobSeeker.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateJobSeeker(String id, Map<String, dynamic> data) async {
    await _loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/job-seekers/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      debugPrint('❌ Error updating job seeker: $e');
      return false;
    }
  }

  // ==================== Bakery Ads ====================
  
  static Future<List<BakeryAd>> getBakeryAds({
    BakeryAdType? type,
    String? location,
    String? search,
    String? province,
    int? minPrice,
    int? maxPrice,
    int? minFlourQuota,
    int? maxFlourQuota,
    int page = 1,
    bool useCache = true,
  }) async {
    final canUseCache = useCache && page == 1 && type == null && location == null && search == null;
    
    try {
      final params = <String, String>{
        'page': page.toString(),
        if (type != null) 'type': type == BakeryAdType.sale ? 'sale' : 'rent',
        if (location != null) 'location': location,
        if (search != null) 'search': search,
        if (province != null) 'province': province,
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
        if (minFlourQuota != null) 'minFlourQuota': minFlourQuota.toString(),
        if (maxFlourQuota != null) 'maxFlourQuota': maxFlourQuota.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/bakery-ads').replace(queryParameters: params);
      final response = await http.get(uri);
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final list = data['data'] as List;
        if (canUseCache) {
          await CacheService.cacheBakeries(List<Map<String, dynamic>>.from(list));
        }
        return list.map((json) => BakeryAd.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching bakery ads: $e');
      if (canUseCache) {
        final cached = await CacheService.getBakeries();
        if (cached != null) {
          debugPrint('📦 Using cached bakeries');
          return cached.map((json) => BakeryAd.fromJson(json)).toList();
        }
      }
      return [];
    }
  }

  static Future<bool> createBakeryAd(Map<String, dynamic> adData) async {
    await _loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bakery-ads'),
        headers: _headers,
        body: jsonEncode(adData),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BakeryAd>> getMyBakeryAds() async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bakery-ads/my/list'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return (data['data'] as List).map((json) => BakeryAd.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateBakeryAd(String id, Map<String, dynamic> adData) async {
    await _loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bakery-ads/$id'),
        headers: _headers,
        body: jsonEncode(adData),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Error updating bakery ad: $e');
      return false;
    }
  }

  // ==================== Equipment Ads ====================
  
  static Future<List<Map<String, dynamic>>> getEquipmentAds({
    String? condition,
    String? location,
    String? search,
    int page = 1,
    bool useCache = true,
  }) async {
    final canUseCache = useCache && page == 1 && condition == null && location == null && search == null;
    
    try {
      final params = <String, String>{
        'page': page.toString(),
        if (condition != null) 'condition': condition,
        if (location != null) 'location': location,
        if (search != null) 'search': search,
      };
      
      final uri = Uri.parse('$baseUrl/equipment-ads').replace(queryParameters: params);
      final response = await http.get(uri);
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final list = List<Map<String, dynamic>>.from(data['data']);
        if (canUseCache) {
          await CacheService.cacheEquipment(list);
        }
        return list;
      }
      return [];
    } catch (e) {
      if (canUseCache) {
        final cached = await CacheService.getEquipment();
        if (cached != null) {
          debugPrint('📦 Using cached equipment');
          return cached;
        }
      }
      return [];
    }
  }

  static Future<bool> createEquipmentAd(Map<String, dynamic> adData) async {
    await _loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/equipment-ads'),
        headers: _headers,
        body: jsonEncode(adData),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<EquipmentAd>> getMyEquipmentAds() async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipment-ads/my/list'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return (data['data'] as List).map((json) => EquipmentAd.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateEquipmentAd(String id, Map<String, dynamic> adData) async {
    await _loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/equipment-ads/$id'),
        headers: _headers,
        body: jsonEncode(adData),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Error updating equipment ad: $e');
      return false;
    }
  }

  // ==================== Upload ====================
  
  /// آپلود عکس با فشرده‌سازی خودکار
  static Future<String?> uploadImage(File file, {bool compress = true}) async {
    await _loadToken();
    try {
      // فشرده‌سازی عکس قبل از آپلود
      File uploadFile = file;
      if (compress && MediaCompressor.needsCompression(file)) {
        debugPrint('🗜️ Compressing image before upload...');
        final compressed = await MediaCompressor.compressImage(file);
        if (compressed != null) {
          uploadFile = compressed;
        }
      }

      debugPrint('📤 Uploading to: $baseUrl/upload/image');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/image'));
      request.headers['Authorization'] = 'Bearer $_token';
      
      String ext = uploadFile.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'gif') {
        mimeType = 'image/gif';
      } else if (ext == 'webp') {
        mimeType = 'image/webp';
      }
      
      request.files.add(await http.MultipartFile.fromPath(
        'image', 
        uploadFile.path,
        contentType: MediaType.parse(mimeType),
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('📥 Upload response: ${response.body}');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return data['data']['url'];
      }
      debugPrint('❌ Upload failed: ${data['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// آپلود چند عکس با فشرده‌سازی خودکار
  static Future<List<String>> uploadImages(List<File> files, {bool compress = true}) async {
    await _loadToken();
    try {
      // فشرده‌سازی عکس‌ها
      List<File> uploadFiles = files;
      if (compress) {
        debugPrint('🗜️ Compressing ${files.length} images...');
        uploadFiles = await MediaCompressor.compressImages(files);
      }

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/images'));
      request.headers['Authorization'] = 'Bearer $_token';
      
      for (var file in uploadFiles) {
        request.files.add(await http.MultipartFile.fromPath('images', file.path));
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return (data['data'] as List).map((f) => f['url'] as String).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Upload images error: $e');
      return [];
    }
  }

  /// آپلود ویدیو با فشرده‌سازی خودکار
  static Future<String?> uploadVideo(
    File file, {
    bool compress = true,
    void Function(double)? onProgress,
  }) async {
    await _loadToken();
    try {
      File uploadFile = file;
      
      // فشرده‌سازی ویدیو
      if (compress) {
        debugPrint('🗜️ Compressing video...');
        final compressed = await MediaCompressor.compressVideo(
          file,
          onProgress: onProgress,
        );
        if (compressed != null) {
          uploadFile = compressed;
        }
      }

      debugPrint('📤 Uploading video: ${MediaCompressor.getFileSize(uploadFile)}');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/video'));
      request.headers['Authorization'] = 'Bearer $_token';
      
      request.files.add(await http.MultipartFile.fromPath(
        'video', 
        uploadFile.path,
        contentType: MediaType.parse('video/mp4'),
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('📥 Video upload response: ${response.body}');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return data['data']['url'];
      }
      debugPrint('❌ Video upload failed: ${data['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ Video upload error: $e');
      return null;
    }
  }

  // ==================== Notifications ====================
  
  static Future<List<Map<String, dynamic>>> getNotifications({int page = 1}) async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications?page=$page'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications?page=1&limit=1'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      return data['unreadCount'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ==================== Statistics ====================
  
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/statistics'));
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return data['data'];
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ==================== Chat ====================
  
  static Future<List<Map<String, dynamic>>> getConversations() async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/conversations'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMessages(int recipientId) async {
    await _loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/messages/$recipientId'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final messages = List<Map<String, dynamic>>.from(data['data']);
        // رمزگشایی پیام‌ها - کلید بر اساس recipientId ساخته شده
        for (var msg in messages) {
          if (msg['message'] != null && msg['isEncrypted'] == true) {
            try {
              msg['message'] = await EncryptionService.decryptMessage(msg['message'], recipientId);
              debugPrint('🔓 Message decrypted successfully');
            } catch (e) {
              debugPrint('⚠️ Decryption failed: $e');
            }
          }
        }
        return messages;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Get messages error: $e');
      return [];
    }
  }

  static Future<bool> sendMessage(int receiverId, String message, {int? replyToId, bool encrypt = true}) async {
    await _loadToken();
    try {
      // رمزنگاری پیام
      String finalMessage = message;
      bool isEncrypted = false;
      
      if (encrypt) {
        try {
          finalMessage = await EncryptionService.encryptMessage(message, receiverId);
          isEncrypted = true;
          debugPrint('🔐 Message encrypted successfully');
        } catch (e) {
          debugPrint('⚠️ Encryption failed, sending plain text: $e');
          finalMessage = message;
          isEncrypted = false;
        }
      }
      
      debugPrint('📨 Sending message to $receiverId (encrypted: $isEncrypted)');
      
      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: _headers,
        body: jsonEncode({
          'receiverId': receiverId,
          'message': finalMessage,
          'isEncrypted': isEncrypted,
          if (replyToId != null) 'replyToId': replyToId,
        }),
      );
      
      debugPrint('📨 Response: ${response.body}');
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Send message error: $e');
      return false;
    }
  }

  // ارسال فایل در چت
  static Future<Map<String, dynamic>?> sendChatMedia(int receiverId, File file, String messageType, {int? replyToId}) async {
    await _loadToken();
    try {
      debugPrint('📤 sendChatMedia: receiverId=$receiverId, type=$messageType, path=${file.path}');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chat/send-media'));
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['receiverId'] = receiverId.toString();
      request.fields['messageType'] = messageType;
      if (replyToId != null) request.fields['replyToId'] = replyToId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      debugPrint('📤 Sending request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('📤 Response status: ${response.statusCode}');
      debugPrint('📤 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        debugPrint('✅ Media sent successfully');
        return data['data'];
      }
      debugPrint('❌ Media send failed: ${data['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ sendChatMedia error: $e');
      return null;
    }
  }

  // وضعیت آنلاین
  static Future<void> setOnline() async {
    await _loadToken();
    try {
      await http.post(Uri.parse('$baseUrl/chat/online'), headers: _headers);
    } catch (_) {}
  }

  static Future<void> setOffline() async {
    await _loadToken();
    try {
      await http.post(Uri.parse('$baseUrl/chat/offline'), headers: _headers);
    } catch (_) {}
  }

  // تایپ کردن
  static Future<void> sendTyping(int receiverId) async {
    await _loadToken();
    try {
      await http.post(Uri.parse('$baseUrl/chat/typing/$receiverId'), headers: _headers);
    } catch (_) {}
  }

  static Future<bool> isTyping(int senderId) async {
    await _loadToken();
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/typing/$senderId'), headers: _headers);
      final data = jsonDecode(response.body);
      return data['isTyping'] == true;
    } catch (_) {
      return false;
    }
  }

  // بلاک کردن
  static Future<bool> blockUser(int userId) async {
    await _loadToken();
    try {
      final response = await http.post(Uri.parse('$baseUrl/chat/block/$userId'), headers: _headers);
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unblockUser(int userId) async {
    await _loadToken();
    try {
      final response = await http.delete(Uri.parse('$baseUrl/chat/block/$userId'), headers: _headers);
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBlocked(int userId) async {
    await _loadToken();
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/is-blocked/$userId'), headers: _headers);
      final data = jsonDecode(response.body);
      return data['isBlocked'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getChatUser(int userId) async {
    await _loadToken();
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/user/$userId'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==================== Helper ====================
  
  // ==================== Delete Ads ====================
  
  static Future<bool> deleteAd(String type, String id) async {
    await _loadToken();
    try {
      String endpoint;
      switch (type) {
        case 'job-ad':
          endpoint = 'job-ads';
          break;
        case 'job-seeker':
          endpoint = 'job-seekers';
          break;
        case 'bakery-ad':
          endpoint = 'bakery-ads';
          break;
        case 'equipment-ad':
          endpoint = 'equipment-ads';
          break;
        default:
          return false;
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint/$id'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Error deleting ad: $e');
      return false;
    }
  }

  // ==================== Helper ====================
  
  static bool get isLoggedIn => _token != null;
  
  static Future<bool> checkAuth() async {
    await _loadToken();
    return _token != null;
  }
}
