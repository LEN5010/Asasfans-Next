/// Bilibili identifiers stay strings, including MIDs above safe JSON doubles.
bool validBilibiliMid(String value) =>
    RegExp(r'^[1-9]\d{0,19}$').hasMatch(value);
bool validBvid(String value) => RegExp(r'^BV[0-9A-Za-z]{10}$').hasMatch(value);
