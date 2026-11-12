import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'fullscreen_gallery.dart';

/// معرض صور المنتج: يعرض الصور بالسحب (PageView) مع نقاط تدل على العدد
/// الحالي، وبالضغط على أي صورة تنفتح بملء الشاشة قابلة للتكبير.
/// إذا ما في صور، يرجع للإيموجي كبديل زي القديم.
class ProductImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String emoji;
  final Color background;
  final double height;

  /// عنصر اختياري يُرسم فوق الصورة مباشرة (مثل زر المفضّلة).
  final Widget? overlay;

  const ProductImageGallery({
    super.key,
    required this.imageUrls,
    required this.emoji,
    required this.background,
    this.height = 190,
    this.overlay,
  });

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    if (urls.isEmpty) {
      return Stack(
        children: [
          Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(color: widget.background, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(widget.emoji.isEmpty ? '📦' : widget.emoji, style: const TextStyle(fontSize: 64)),
          ),
          if (widget.overlay != null) widget.overlay!,
        ],
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => openFullscreenGallery(
                      context: context,
                      itemCount: urls.length,
                      initialIndex: index,
                      imageBuilder: (context, i) => CachedNetworkImage(
                        imageUrl: urls[i],
                        fit: BoxFit.contain,
                      ),
                    ),
                    child: Container(
                      color: widget.background,
                      child: CachedNetworkImage(
                        imageUrl: urls[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: 800,
                        errorWidget: (context, url, error) => Center(
                          child: Text(widget.emoji.isEmpty ? '📦' : widget.emoji,
                              style: const TextStyle(fontSize: 64)),
                        ),
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.overlay != null) widget.overlay!,
            if (urls.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_current + 1}/${urls.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10.5)),
                  ),
                ),
              ),
          ],
        ),
        if (urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i ? AppColors.teal : AppColors.sandLine,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
