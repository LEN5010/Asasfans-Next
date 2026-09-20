import 'package:asasfans_next/core/domain/request_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completed stream can detach without retaining media callbacks until the whole session ends',
    () {
      final token = RequestCancellation();
      var first = 0, second = 0;
      final detach = token.onCancel(() => first++);
      token.onCancel(() => second++);
      detach();
      token.cancel();
      token.cancel();
      expect(first, 0);
      expect(second, 1);
      token.onCancel(() => first++);
      expect(first, 1);
    },
  );
  test(
    'callbacks can detach during cancellation without mutating its iteration',
    () {
      final token = RequestCancellation();
      void Function()? detach;
      token.onCancel(() => detach?.call());
      var calls = 0;
      detach = token.onCancel(() => calls++);
      token.cancel();
      expect(calls, 1);
    },
  );
}
