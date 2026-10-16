import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/media_image_policy.dart';
import '../application/content_providers.dart';
import 'fanart_image_viewer.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/member_tone.dart';

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
    // Without a picture a member's account still shows her colour.
    final member = AppTheme.membersIn(name).firstOrNull;
    final tone = member == null
        ? null
        : MemberTone.of(member, Theme.of(context).brightness);
    final fallback = ColoredBox(
      color: tone?.wash ?? colors.primaryContainer,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: TextStyle(
            color: tone?.text ?? colors.onPrimaryContainer,
            fontSize: size * .4,
            fontWeight: FontWeight.w600,
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
              : Image(
                  image: MediaImagePolicy.preview(
                    image!,
                    logicalWidth: size,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// Asked once per launch before members who have left are shown: their
/// content is an archive, and some of it may upset people.
Future<bool> confirmMoreMembers(BuildContext context) async {
  if (_moreMembersAccepted) return true;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.info_outline),
      title: const Text('查看更多成员'),
      content: const Text(
        '以下成员不属于 A-SOUL 现役成员，相关内容仅作为公开内容的存档展示，'
        '部分内容可能引起不适，请谨慎查看。\n\n'
        '免责声明：Asasfans Next 是非官方粉丝项目，与 A-SOUL 及相关公司无关。'
        '内容版权归原作者所有，展示不代表本应用立场；'
        '如有不当内容，请通过 GitHub Issues 反馈处理。',
      ),
      actions: [
        AppButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        AppButton(
          selected: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('我已了解，继续'),
        ),
      ],
    ),
  );
  if (accepted == true) _moreMembersAccepted = true;
  return _moreMembersAccepted;
}

var _moreMembersAccepted = false;

/// A member as a filter option, as the dynamics panel draws it: her account
/// picture and a name. [members] are the short names whose pictures to show,
/// two overlapping for a pair such as 心宜&思诺; the pictures come from the
/// dynamics roster unless [image] is given, and until it loads each is her
/// initial in her colour.
class MemberChoiceButton extends ConsumerWidget {
  const MemberChoiceButton({
    super.key,
    required this.label,
    required this.members,
    required this.selected,
    required this.onPressed,
    this.image,
  });
  final String label;
  final List<String> members;
  final bool selected;
  final VoidCallback? onPressed;
  final Uri? image;

  static const size = 28.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatars = image != null
        ? const <String, Uri>{}
        : ref.watch(memberAvatarsProvider);
    Uri? pictureOf(String member) => image ?? avatars[member];
    final ring = Theme.of(context).colorScheme.surface;
    return AppButton(
      tooltip: label,
      selected: selected,
      tonal: true,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size + size / 2 * (members.length - 1),
            height: size,
            child: Stack(
              children: [
                for (final (i, member) in members.indexed)
                  Positioned(
                    left: size / 2 * i,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: i == 0
                            ? null
                            : Border.all(color: ring, width: 1.5),
                      ),
                      child: ContentAvatar(
                        name: member,
                        image: pictureOf(member),
                        size: size,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// A single image keeps its ratio inside a bounded box, so a portrait photo
/// is not as tall as the screen; a very long one shows its top with a 长图
/// mark. Sets are a contact sheet of square cells at a thumbnail size, not
/// stretched across the column. All thumbnails open the existing
/// original-size viewer, including long images.
class ContentImageGallery extends StatelessWidget {
  const ContentImageGallery({
    super.key,
    required this.images,
    this.aspectRatios = const {},
    this.preview = false,
  });
  final List<Uri> images;
  final Map<Uri, double> aspectRatios;
  final bool preview;

  /// The box a single image fits in, and the width of a set's sheet.
  static const singleBound = 400.0;
  static const sheetWidth = 420.0;

  /// Narrower than 3:4, an image is a long one: its top is shown.
  static const longRatio = 3 / 4;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    Widget image(int index, {bool square = false}) {
      final uri = images[index];
      final ratio = aspectRatios[uri];
      final long = !square && !preview && ratio != null && ratio < longRatio;
      // A lone image of unknown shape takes its own once loaded, within
      // the bound; every other image fills the width it is given.
      final free = !square && !preview && ratio == null;
      // Decoded for the width it is drawn at; the viewer opens the original.
      final photo = LayoutBuilder(
        builder: (context, constraints) => Image(
          image: MediaImagePolicy.preview(
            uri,
            logicalWidth: constraints.maxWidth,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          width: free ? null : double.infinity,
          height: long ? double.infinity : null,
          fit: square || long
              ? BoxFit.cover
              : preview
              ? BoxFit.contain
              : BoxFit.fitWidth,
          alignment: long ? Alignment.topCenter : Alignment.center,
          errorBuilder: (_, _, _) => SizedBox(
            width: free ? singleBound / 2 : null,
            height: 100,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
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
                if (square || ratio != null || preview)
                  AspectRatio(
                    aspectRatio: square
                        ? 1
                        : preview
                        ? 16 / 9
                        : long
                        ? longRatio
                        : ratio!,
                    child: photo,
                  )
                else
                  photo,
                if (long)
                  const Positioned(right: 8, bottom: 8, child: _Mark('长图')),
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

    if (preview) {
      return Stack(
        children: [
          image(0),
          if (images.length > 1)
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${images.length} 张图片',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    if (images.length == 1) {
      // Within a square bound, at the image's own shape: a wide photo
      // is as wide as the bound, a tall one as tall as it.
      final ratio = aspectRatios[images.first];
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ratio == null
                ? singleBound
                : singleBound * math.min(1, math.max(ratio, longRatio)),
            maxHeight: ratio == null ? singleBound : double.infinity,
          ),
          child: image(0),
        ),
      );
    }
    final count = images.length.clamp(0, 9);
    final columns = count == 2 || count == 4 ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns keep the cell size of three, so a pair is no larger
        // per picture than a set of nine.
        final sheet = math.min(constraints.maxWidth, sheetWidth);
        final cell = (sheet - 2 * 6) / 3;
        final width = columns == 3
            ? cell
            : math.min(cell * 1.25, (constraints.maxWidth - 6) / 2);
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

/// A small dark label on a picture's corner.
class _Mark extends StatelessWidget {
  const _Mark(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    ),
  );
}
