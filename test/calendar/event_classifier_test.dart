import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/calendar/domain/event_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  String title = '',
  String location = '',
  String description = '',
  List<String> categories = const [],
  bool allDay = false,
  EventStatus status = EventStatus.confirmed,
  String? url,
}) => CalendarEvent(
  uid: '1',
  title: title,
  start: DateTime.utc(2026, 9, 21, 20),
  end: DateTime.utc(2026, 9, 21, 22),
  allDay: allDay,
  status: status,
  location: location,
  description: description,
  categories: categories,
  sourceUrl: url == null ? null : Uri.parse(url),
);

void main() {
  test('a live room link is a livestream regardless of wording', () {
    expect(
      EventClassifier.classify(
        _event(title: '不含关键词', url: 'https://live.bilibili.com/22625025'),
      ),
      EventKind.live,
    );
  });

  test('live keywords in title, location or categories all count', () {
    expect(EventClassifier.classify(_event(title: '嘉然杂谈')), EventKind.live);
    expect(EventClassifier.classify(_event(location: '线下')), EventKind.live);
    expect(
      EventClassifier.classify(_event(categories: ['歌会'])),
      EventKind.live,
    );
  });

  test('a non-live keyword wins when no live keyword is present', () {
    expect(EventClassifier.classify(_event(title: '专辑首发')), EventKind.other);
    expect(EventClassifier.classify(_event(title: '周边上架')), EventKind.other);
  });

  test('an all-day entry is never classified as a livestream', () {
    // A birthday is kept in the model but is not a broadcast.
    expect(
      EventClassifier.classify(_event(title: '嘉然生日直播', allDay: true)),
      EventKind.other,
    );
  });

  test('a cancelled entry is not offered as a livestream', () {
    expect(
      EventClassifier.classify(
        _event(title: '直播', status: EventStatus.cancelled),
      ),
      EventKind.other,
    );
  });

  test('an unlabelled timed entry defaults to a broadcast', () {
    expect(EventClassifier.classify(_event(title: '未标注')), EventKind.live);
  });

  test('members are detected through their aliases', () {
    expect(EventClassifier.members(_event(title: '嘉然的直播')), ['嘉然']);
    expect(EventClassifier.members(_event(title: 'Diana solo')), ['嘉然']);
    expect(EventClassifier.members(_event(title: '贝拉 乃琳 联动')), ['贝拉', '乃琳']);
  });

  test('member order is stable regardless of mention order', () {
    expect(
      EventClassifier.members(_event(title: '乃琳 贝拉')),
      EventClassifier.members(_event(title: '贝拉 乃琳')),
    );
  });

  test('an event naming nobody yields no members', () {
    expect(EventClassifier.members(_event(title: '公告')), isEmpty);
  });
}
