import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a complete ordered range is accepted', () {
    final query = DynamicQuery(
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 1, 31, 23, 59, 59),
    );
    expect(query.isServerAcceptable, isTrue);
  });

  test(
    'an inverted or empty range is rejected before it reaches the server',
    () {
      final inverted = DynamicQuery(
        from: DateTime.utc(2026, 2, 1),
        to: DateTime.utc(2026, 1, 1),
      );
      expect(inverted.isServerAcceptable, isFalse);

      final same = DateTime.utc(2026, 1, 1);
      expect(
        DynamicQuery(from: same, to: same).isServerAcceptable,
        isFalse,
        reason: 'the server rejects an empty range',
      );
    },
  );

  test('a range covering one whole day stays ordered', () {
    // The picker returns midnight for both ends; the view extends the end to
    // the last second so a single-day range is not empty.
    final day = DateTime(2026, 3, 5);
    final query = DynamicQuery(
      from: day,
      to: DateTime(day.year, day.month, day.day, 23, 59, 59),
    );
    expect(query.isServerAcceptable, isTrue);
  });

  test('clearRange drops both ends together', () {
    final query = DynamicQuery(
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 2, 1),
    ).copyWith(clearRange: true);
    expect(query.from, isNull);
    expect(query.to, isNull);
  });

  test('a member id must be the server form, not a bare number', () {
    expect(const DynamicQuery(memberId: 'uid:123').isServerAcceptable, isTrue);
    expect(
      const DynamicQuery(memberId: '123').isServerAcceptable,
      isFalse,
      reason: 'a bare number is not a server member id',
    );
  });

  test('clearMember removes the member without touching other filters', () {
    final query = const DynamicQuery(
      memberId: 'uid:123',
      keyword: '生日',
      type: DynamicType.video,
    ).copyWith(clearMember: true);
    expect(query.memberId, isNull);
    expect(query.keyword, '生日');
    expect(query.type, DynamicType.video);
  });

  test('filters combine without clearing one another', () {
    final query = const DynamicQuery()
        .copyWith(keyword: '演唱会')
        .copyWith(memberId: 'uid:9')
        .copyWith(type: DynamicType.image)
        .copyWith(from: DateTime.utc(2026, 1, 1), to: DateTime.utc(2026, 6, 1));
    expect(query.keyword, '演唱会');
    expect(query.memberId, 'uid:9');
    expect(query.type, DynamicType.image);
    expect(query.from, isNotNull);
    expect(query.isServerAcceptable, isTrue);
  });
}
