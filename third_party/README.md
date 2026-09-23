# Reference implementation notices

The glass chrome integration and release-to-commit navigation handling in
`lib/shared/widgets/glass/` are adapted from LoveIwara, revision
`888d4b95ff052299c11151b9013605955a776ccc`:

- `lib/app/ui/widgets/glass/liquid_glass_material.dart`
- `lib/app/ui/widgets/glass/glass_tokens.dart`
- `lib/app/ui/widgets/glass/glass_floating_tab_bar.dart`
- `lib/app/ui/widgets/glass/glass_content_brightness.dart`

Copyright (c) 2024 i_iwara. Licensed under the MIT License; see
[LoveIwara-LICENSE](LoveIwara-LICENSE). No LoveIwara branding, pages, services or
account/player implementation is included.

The `liquid_glass_widgets` package remains a pinned external dependency with its
own license, included by Flutter's package-license registry.

## Archive display references

Dynamic cards, image sizing and reservation date presentation follow the DTO and
UI in the user's local `dynamic_asoul`, revision `cf4dcc3`. No account, scraper or
remote-favorites implementation is copied.

Three original sticker images from `img/心宜和思诺的交响乐谱/原图/` are included
under `assets/stickers/` for the exact labels shown in the user's feedback:
`举高高` → `lift.png`, `吃饭` → `meal.png`, `晚安喵` → `goodnight.png`.
Artwork rights remain with the original creators; the application license does
not relicense these images. Other stickers use their archive-provided URLs.

`flutter_staggered_grid_view` 0.7.0 is a pinned dependency; its MIT license is
included by Flutter's package-license registry.
