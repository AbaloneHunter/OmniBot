import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/pages/chat/widgets/chat_spotlight_tour.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
import 'package:ui/theme/app_theme.dart';

class _TourHarness extends StatefulWidget {
  const _TourHarness();

  @override
  State<_TourHarness> createState() => _TourHarnessState();
}

class _TourHarnessState extends State<_TourHarness> {
  int step = 0;
  int finishCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(
              key: ValueKey('actual-chat-page-under-tour'),
              color: Colors.white,
            ),
            ChatSpotlightTour(
              step: step,
              onBack: () {
                if (step == 0) return;
                setState(() => step -= 1);
              },
              onNext: () => setState(() => step += 1),
              onFinish: () => setState(() => finishCount += 1),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('spotlight tour overlays chat and keeps navigation at bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _TourHarness());

    expect(
      find.byKey(const ValueKey('actual-chat-page-under-tour')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-spotlight-tour')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-spotlight-card-0')), findsOneWidget);
    expect(find.text('菜单与会话'), findsOneWidget);

    final back = find.byKey(const ValueKey('chat-spotlight-back'));
    final next = find.byKey(const ValueKey('chat-spotlight-next'));
    expect(tester.getBottomLeft(back).dy, greaterThan(620));
    expect(tester.getBottomRight(next).dy, greaterThan(620));

    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-spotlight-card-1')), findsOneWidget);
    expect(find.text('选择工作模式'), findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-spotlight-card-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
