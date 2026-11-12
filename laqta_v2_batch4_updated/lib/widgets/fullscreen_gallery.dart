import 'package:flutter/material.dart';

/// يفتح عارض صور بملء الشاشة قابل للتكبير (Pinch to zoom)، مع إمكانية
/// التنقل بين عدة صور بالسحب يمينًا/يسارًا. يُستخدم لصور المنتج سواء
/// كانت مرفوعة على الخادم (شبكة) أو صور محليّة لسا ما انرفعت.
Future<void> openFullscreenGallery({
  required BuildContext context,
  required int itemCount,
  required int initialIndex,
  required Widget Function(BuildContext context, int index) imageBuilder,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, __) => _FullscreenGalleryPage(
        itemCount: itemCount,
        initialIndex: initialIndex,
        imageBuilder: imageBuilder,
      ),
    ),
  );
}

class _FullscreenGalleryPage extends StatefulWidget {
  final int itemCount;
  final int initialIndex;
  final Widget Function(BuildContext context, int index) imageBuilder;

  const _FullscreenGalleryPage({
    required this.itemCount,
    required this.initialIndex,
    required this.imageBuilder,
  });

  @override
  State<_FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<_FullscreenGalleryPage> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: widget.imageBuilder(context, index)),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          if (widget.itemCount > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_current + 1} / ${widget.itemCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
