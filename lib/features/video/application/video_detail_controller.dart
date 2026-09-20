import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../domain/video_detail.dart';

class VideoDetailController extends ChangeNotifier {
  VideoDetailController(this._repository, this.bvid);
  final VideoRepository _repository;
  final String bvid;
  VideoDetail? detail;
  String? _selectedCid;
  VideoPart? get selectedPart =>
      detail?.parts.where((part) => part.cid == _selectedCid).firstOrNull ??
      detail?.parts.first;
  void selectPart(String cid) {
    if (_closed ||
        cid == _selectedCid ||
        detail?.parts.any((part) => part.cid == cid) != true) {
      return;
    }
    _selectedCid = cid;
    notifyListeners();
  }

  ApiFailure? failure;
  bool loading = false;
  bool _closed = false;
  int _generation = 0;
  RequestCancellation? _request;
  Future<void> refresh() async {
    if (_closed) return;
    final generation = ++_generation;
    _request?.cancel();
    final request = _request = RequestCancellation();
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final value = await _repository.detail(bvid, cancellation: request);
      if (_closed || generation != _generation) return;
      if (value.video.identity.value != bvid) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      detail = value;
      if (!value.parts.any((part) => part.cid == _selectedCid)) {
        _selectedCid = value.parts.first.cid;
      }
    } catch (error) {
      if (_closed || generation != _generation) return;
      failure = error is ApiFailure
          ? error
          : const ApiFailure(ApiFailureKind.invalidResponse);
      if ([
        ApiFailureKind.loginRequired,
        ApiFailureKind.forbidden,
        ApiFailureKind.notFound,
      ].contains(failure!.kind)) {
        detail = null;
      }
    } finally {
      if (!_closed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _request?.cancel();
    super.dispose();
  }
}
