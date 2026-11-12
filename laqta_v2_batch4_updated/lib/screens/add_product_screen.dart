import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/db_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/fullscreen_gallery.dart';

/// عنصر صورة واحد بنموذج الإضافة: إما صورة موجودة مسبقًا على الخادم
/// (بوضع التعديل)، أو صورة محليّة لسا ما انرفعت اختارها المستخدم الآن.
class _PickedImage {
  final String? url;
  final Uint8List? bytes;
  const _PickedImage.existing(String this.url) : bytes = null;
  const _PickedImage.local(Uint8List this.bytes) : url = null;
}

const int _kMaxImages = 6;

class AddProductScreen extends StatefulWidget {
  final AppState appState;
  const AddProductScreen({super.key, required this.appState});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final List<_PickedImage> _images = [];
  bool _submitting = false;

  Product? get _editing => widget.appState.editingProduct;
  bool get _isEditing => _editing != null;

  @override
  void initState() {
    super.initState();
    final p = _editing;
    if (p != null) {
      _titleCtrl.text = p.title;
      _priceCtrl.text = p.price % 1 == 0 ? p.price.toStringAsFixed(0) : p.price.toString();
      _descCtrl.text = p.desc;
      _phoneCtrl.text = p.contactPhone ?? '';
      _addressCtrl.text = p.contactAddress ?? '';
      _images.addAll(p.imageUrls.map((u) => _PickedImage.existing(u)));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.appState.setAddFormCategory(p.cat);
        widget.appState.setAddFormCondition(p.cond);
      });
    }
  }

  /// نقرأ الصور كبايتات مباشرة (بدل dart:io File) عشان تشتغل على
  /// الموبايل وسطح المكتب والويب بدون أي فرق. يسمح باختيار أكثر من صورة
  /// دفعة وحدة، وبالضغط على "إضافة" مرة ثانية لإضافة المزيد لحد الحد الأقصى.
  Future<void> _pickImages() async {
    final remaining = _kMaxImages - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الحد الأقصى $_kMaxImages صور لكل منتج')),
      );
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    final newImages = <_PickedImage>[];
    for (final x in toAdd) {
      newImages.add(_PickedImage.local(await x.readAsBytes()));
    }
    if (!mounted) return;
    setState(() => _images.addAll(newImages));

    if (picked.length > toAdd.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم اختيار أول $_kMaxImages صور فقط (الحد الأقصى)')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _viewImage(int index) {
    openFullscreenGallery(
      context: context,
      itemCount: _images.length,
      initialIndex: index,
      imageBuilder: (context, i) {
        final img = _images[i];
        return img.url != null
            ? CachedNetworkImage(imageUrl: img.url!, fit: BoxFit.contain)
            : Image.memory(img.bytes!, fit: BoxFit.contain);
      },
    );
  }

  Future<void> _submitToBackend(AppState appState) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final title = _titleCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();
    final price = double.tryParse(priceText);
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (title.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى التأكد من اسم المنتج والسعر')));
      return;
    }
    if (phone.isEmpty || phone.length < 9) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إدخال رقم هاتف صحيح للتواصل')));
      return;
    }
    if (address.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إدخال عنوانك')));
      return;
    }

    setState(() => _submitting = true);
    try {
      // نرفع الصور المحليّة الجديدة فقط، ونحافظ على ترتيب الصور كما
      // اختاره المستخدم (صور موجودة مسبقًا + صور جديدة).
      final imageUrls = <String>[];
      for (final img in _images) {
        if (img.url != null) {
          imageUrls.add(img.url!);
        } else if (img.bytes != null) {
          final uploaded = await StorageService.instance.uploadProductImage(
            bytes: img.bytes!,
            sellerUid: user.id,
          );
          imageUrls.add(uploaded);
        }
      }

      if (_isEditing) {
        await DbService.instance
            .updateProduct(
              productId: _editing!.firestoreId!,
              title: title,
              price: price,
              cat: appState.addFormCat,
              cond: appState.addFormCond,
              desc: _descCtrl.text.trim(),
              contactPhone: phone,
              contactAddress: address,
              imageUrls: imageUrls,
            )
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw Exception('انتهت مهلة الاتصال بالخادم، يرجى التحقق من الإنترنت والمحاولة مرة أخرى'),
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التعديلات، وسيُعاد عرض الإعلان بعد مراجعته')),
        );
        appState.editingProduct = null;
        appState.back();
        return;
      }

      final meta = user.userMetadata;
      final sellerName = (meta == null ? null : meta['name'] as String?) ?? user.email ?? 'بائع';
      await DbService.instance
          .addProduct(
            title: title,
            price: price,
            cat: appState.addFormCat,
            cond: appState.addFormCond,
            desc: _descCtrl.text.trim(),
            sellerUid: user.id,
            sellerName: sellerName,
            contactPhone: phone,
            contactAddress: address,
            imageUrls: imageUrls,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('انتهت مهلة الاتصال بالخادم، يرجى التحقق من الإنترنت والمحاولة مرة أخرى'),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إرسال المنتج للمراجعة بنجاح')));
      _titleCtrl.clear();
      _priceCtrl.clear();
      _descCtrl.clear();
      _phoneCtrl.clear();
      _addressCtrl.clear();
      setState(() => _images.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الحفظ، يرجى المحاولة مرة أخرى')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        SubHeader(title: _isEditing ? 'تعديل الإعلان' : 'إضافة منتج جديد', onBack: appState.back),
        _imagesPicker(),
        _field('رقم هاتف التواصل',
            child: _textInput(_phoneCtrl, '07XXXXXXXX', keyboardType: TextInputType.phone)),
        _field('عنوانك (مكان الاستلام)',
            child: _textInput(_addressCtrl, 'مثال: عمّان - جبل الحسين - شارع الجامعة')),
        _field('اسم المنتج',
            child: _textInput(_titleCtrl, 'مثال: ساعة جيب نحاسية عتيقة')),
        _field('الفئة',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategories.map((c) {
                final active = appState.addFormCat == c.id;
                return GestureDetector(
                  onTap: () => setState(() => appState.setAddFormCategory(c.id)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.teal : AppColors.card,
                      border: Border.all(color: active ? AppColors.teal : AppColors.sandLine),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('${c.icon} ${c.name}',
                        style: AppTextStyles.body(
                            size: 12, color: active ? AppColors.white : AppColors.ink)),
                  ),
                );
              }).toList(),
            )),
        _field('السعر (د.أ)',
            child: _textInput(_priceCtrl, '0.00', keyboardType: TextInputType.number)),
        _field('حالة القطعة',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.sandLine),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: appState.addFormCond,
                  items: kConditions
                      .map((o) => DropdownMenuItem(value: o, child: Text(o, style: AppTextStyles.body(size: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => appState.setAddFormCondition(v));
                  },
                ),
              ),
            )),
        _field('الوصف',
            child: TextField(
              controller: _descCtrl,
              maxLines: 4,
              textAlign: TextAlign.right,
              style: AppTextStyles.body(size: 13),
              decoration: InputDecoration(
                hintText: 'صف القطعة، تاريخها، وأي تفاصيل تهم المشتري...',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.sandLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.sandLine),
                ),
              ),
            )),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : () => _submitToBackend(appState),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? 'حفظ التعديلات' : 'نشر المنتج للمراجعة',
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.bold, color: AppColors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isEditing
              ? 'سيُعاد عرض الإعلان بعد موافقة فريق لَقطة على التعديلات.'
              : 'سيتم مراجعة المنتج من قبل فريق لَقطة قبل نشره في السوق.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 11, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _imagesPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('صور المنتج (${_images.length}/$_kMaxImages)',
              style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold, color: AppColors.tealDark)),
          const SizedBox(height: 6),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length + (_images.length < _kMaxImages ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _addImageTile();
                }
                return _imageTile(index);
              },
            ),
          ),
          const SizedBox(height: 5),
          Text('يمكنك إضافة أكثر من صورة، واضغط على أي صورة لتكبيرها',
              style: AppTextStyles.body(size: 10.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _addImageTile() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sandLine, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📷', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(_images.isEmpty ? 'إضافة صور' : 'إضافة',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 10.5, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _imageTile(int index) {
    final img = _images[index];
    return GestureDetector(
      onTap: () => _viewImage(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.sandLine),
            ),
            child: img.url != null
                ? CachedNetworkImage(imageUrl: img.url!, fit: BoxFit.cover, width: 96, height: 96)
                : Image.memory(img.bytes!, fit: BoxFit.cover, width: 96, height: 96),
          ),
          Positioned(
            top: -4,
            left: -4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
          if (index == 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                ),
                alignment: Alignment.center,
                child: const Text('رئيسية', style: TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold, color: AppColors.tealDark)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _textInput(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: AppTextStyles.body(size: 13),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.sandLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.sandLine),
        ),
      ),
    );
  }
}
