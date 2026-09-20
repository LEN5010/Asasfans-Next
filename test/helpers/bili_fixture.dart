import 'package:asasfans_next/core/bilibili/wbi_signer.dart';

// Public vectors from bili-sdk/docs/misc/sign/wbi.md, not account secrets.
const imageKeyUrl =
    'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png';
const subKeyUrl =
    'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png';
WbiKeys fixtureKeys() => WbiKeys.fromUrls(imageKeyUrl, subKeyUrl);
