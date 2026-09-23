import 'package:flutter/material.dart';

import '../../../shared/widgets/media_cover.dart';
import 'fanart_image_viewer.dart';

class ContentAvatar extends StatelessWidget {
  const ContentAvatar({
    super.key,
    required this.name,
    this.image,
    this.size = 38,
  });
  final String name;
  final Uri? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontSize: size * .4,
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: image == null
              ? fallback
              : Image.network(
                  displayImageUri(image!, width: 96).toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// A single image keeps its ratio; sets use an uncropped contact sheet. All
/// thumbnails open the existing original-size viewer, including long images.
class ContentImageGallery extends StatelessWidget {
  const ContentImageGallery({
    super.key,
    required this.images,
    this.aspectRatios = const {},
  });
  final List<Uri> images;
  final Map<Uri, double> aspectRatios;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    Widget image(int index, {bool square = false}) {
      final uri = images[index];
      final photo = Image.network(
        displayImageUri(uri).toString(),
        width: double.infinity,
        fit: square ? BoxFit.contain : BoxFit.fitWidth,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 100,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
      final ratio = aspectRatios[uri];
      return Semantics(
        button: true,
        label: '查看图片 ${index + 1}，共 ${images.length} 张',
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    FanartImageViewer(images: images, initial: index),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (square || ratio != null)
                  AspectRatio(aspectRatio: square ? 1 : ratio!, child: photo)
                else
                  photo,
                if (index == 8 && images.length > 9)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          '+${images.length - 9}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (images.length == 1) return image(0);
    final count = images.length.clamp(0, 9);
    final columns = count == 2 || count == 4 ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - (columns - 1) * 6) / columns;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < count; index++)
              SizedBox(width: width, child: image(index, square: true)),
          ],
        );
      },
    );
  }
}
