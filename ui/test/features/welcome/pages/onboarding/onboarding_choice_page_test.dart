import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/features/home/pages/chat/chat_page.dart';
import 'package:ui/features/welcome/pages/onboarding/onboarding_choice_page.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
import 'package:ui/services/storage_service.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/provider_vendor_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const terminalChannel = MethodChannel(
    'cn.com.omnimind.bot/SpecialPermissionEvent',
  );
  const assistsChannel = MethodChannel('cn.com.omnimind.bot/AssistCoreEvent');
  late String savedDistribution;
  late List<String> requestedPackageIds;
  late Map<String, dynamic> terminalSnapshot;
  Completer<void>? prepareGate;

  Map<String, dynamic> profilePayload({
    String apiKey = '',
    bool configured = false,
  }) {
    return <String, dynamic>{
      'profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'deepseek-official',
          'name': 'DeepSeek',
          'baseUrl': 'https://api.deepseek.com',
          'apiKey': apiKey,
          'sourceType': 'deepseek',
          'readOnly': false,
          'ready': configured,
          'statusText': '',
          'configured': configured,
          'protocolType': 'deepseek',
          'wireApi': 'chat_completions',
        },
      ],
      'editingProfileId': 'deepseek-official',
    };
  }

  Widget buildTestApp() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OnboardingChoicePage(),
    );
  }

  Future<void> showFinder(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 50));
    if (tester.getCenter(finder).dy < 180) {
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 180),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openToolsPage(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tutorial-system-next')));
    await tester.pumpAndSettle();
    await showFinder(
      tester,
      find.byKey(const ValueKey('tutorial-development-next')),
    );
    await tester.tap(find.byKey(const ValueKey('tutorial-development-next')));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    savedDistribution = '';
    requestedPackageIds = <String>[];
    terminalSnapshot = <String, dynamic>{
      'running': false,
      'completed': false,
      'success': null,
      'progress': 0.0,
      'stage': '',
      'logLines': <String>[],
    };
    prepareGate = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(terminalChannel, (call) async {
      switch (call.method) {
        case 'getEmbeddedTerminalDistribution':
          return 'alpine';
        case 'getEmbeddedTerminalInitSnapshot':
          return terminalSnapshot;
        case 'setEmbeddedTerminalDistribution':
          savedDistribution = (call.arguments as Map)['distribution']
              .toString();
          return savedDistribution;
        case 'prepareTermuxLiveWrapper':
          requestedPackageIds = ((call.arguments as Map)['packageIds'] as List)
              .map((item) => item.toString())
              .toList(growable: false);
          if (prepareGate != null) {
            await prepareGate!.future;
          }
          return <String, dynamic>{
            'success': true,
            'wrapperReady': true,
            'sharedStorageReady': true,
            'message': 'ready',
          };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(assistsChannel, (call) async {
      switch (call.method) {
        case 'listModelProviderProfiles':
          return profilePayload();
        case 'getSceneModelBindings':
          return <Map<String, dynamic>>[];
        case 'saveModelProviderProfile':
          final args = Map<dynamic, dynamic>.from(call.arguments as Map);
          return <String, dynamic>{
            'id': 'deepseek-official',
            'name': args['name'],
            'baseUrl': args['baseUrl'],
            'apiKey': args['apiKey'],
            'sourceType': args['sourceType'],
            'readOnly': false,
            'ready': true,
            'statusText': '',
            'configured': true,
            'protocolType': args['protocolType'],
            'wireApi': args['wireApi'],
          };
        case 'fetchProviderModels':
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'deepseek-chat',
              'displayName': 'DeepSeek Chat',
            },
            <String, dynamic>{
              'id': 'text-embedding-v1',
              'displayName': 'Text Embedding',
            },
          ];
        case 'saveSceneModelBinding':
          return <Map<String, dynamic>>[];
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(terminalChannel, null);
    messenger.setMockMethodCallHandler(assistsChannel, null);
  });

  testWidgets(
    'environment setup uses short pages and a circular progress page',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('选择本地 Linux 系统'), findsOneWidget);
      expect(find.text('首次使用指南'), findsNothing);
      expect(find.text('1/3'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tutorial-system-page')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('tutorial-distribution-alpine')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('tutorial-distribution-ubuntu')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('tutorial-distribution-ubuntu')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('tutorial-system-next')));
      await tester.pumpAndSettle();
      expect(find.text('选择开发环境'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tutorial-environment-general')),
        findsOne,
      );

      final developmentNext = find.byKey(
        const ValueKey('tutorial-development-next'),
      );
      await showFinder(tester, developmentNext);
      await tester.tap(developmentNext);
      await tester.pumpAndSettle();

      expect(find.text('添加需要的开发工具'), findsOneWidget);
      expect(find.text('Ubuntu · 通用开发'), findsOneWidget);

      final startSetup = find.byKey(
        const ValueKey('tutorial-environment-primary'),
      );
      prepareGate = Completer<void>();
      await showFinder(tester, startSetup);
      await tester.tap(startSetup);
      terminalSnapshot = <String, dynamic>{
        ...terminalSnapshot,
        'running': true,
        'progress': 0.24,
        'stage': '正在初始化宿主终端运行时',
      };
      await tester.pump(const Duration(milliseconds: 420));
      await tester.pump();

      expect(find.text('正在准备 Ubuntu 系统'), findsOneWidget);
      expect(find.byIcon(LucideIcons.loaderCircle), findsNothing);
      final activeMilestone = find.byKey(
        const ValueKey('tutorial-environment-active-milestone-spinner'),
      );
      expect(activeMilestone, findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.descendant(
                of: activeMilestone,
                matching: find.byType(CircularProgressIndicator),
              ),
            )
            .value,
        isNull,
      );
      final firstProgress = tester
          .widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('tutorial-environment-progress-ring')),
          )
          .value!;
      expect(firstProgress, greaterThan(0.02));

      terminalSnapshot = <String, dynamic>{
        ...terminalSnapshot,
        'progress': 0.72,
        'stage': '正在安装所选开发工具：nodejs, npm, git, python, pip, uv',
      };
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();

      expect(find.text('正在安装开发工具'), findsOneWidget);
      expect(find.text('安装组件'), findsOneWidget);
      final secondProgress = tester
          .widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('tutorial-environment-progress-ring')),
          )
          .value!;
      expect(secondProgress, greaterThan(firstProgress));

      prepareGate!.complete();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(savedDistribution, 'ubuntu');
      expect(
        requestedPackageIds,
        containsAll(<String>['nodejs', 'python', 'git']),
      );
      expect(
        find.byKey(const ValueKey('tutorial-environment-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tutorial-environment-progress-ring')),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('开发环境已准备完成'), findsOneWidget);
      expect(find.text('继续配置模型'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('later setup pages use bottom back and provider brand icons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 50));

    await openToolsPage(tester);
    final skipEnvironment = find.byKey(
      const ValueKey('tutorial-skip-environment'),
    );
    await showFinder(tester, skipEnvironment);
    await tester.tap(skipEnvironment);
    await tester.pumpAndSettle();

    expect(find.text('选择模型提供商'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-provider-deepseek')), findsOne);
    expect(find.byKey(const ValueKey('tutorial-back-button')), findsNothing);
    expect(find.byKey(const ValueKey('tutorial-bottom-back')), findsOneWidget);
    for (final id in <String>[
      'deepseek',
      'moonshot',
      'mimo',
      'openai',
      'anthropic',
      'custom',
    ]) {
      expect(
        find.byKey(ValueKey<String>('tutorial-provider-icon-$id')),
        findsOneWidget,
      );
    }
    expect(find.byType(ProviderVendorIcon), findsNWidgets(5));

    final bottomBack = find.byKey(const ValueKey('tutorial-bottom-back'));
    await showFinder(tester, bottomBack);
    await tester.tap(bottomBack);
    await tester.pumpAndSettle();

    expect(find.text('添加需要的开发工具'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-back-button')), findsNothing);
    expect(find.byKey(const ValueKey('tutorial-bottom-back')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider models can be assigned before opening the chat guide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 50));

    await openToolsPage(tester);
    final skipEnvironment = find.byKey(
      const ValueKey('tutorial-skip-environment'),
    );
    await showFinder(tester, skipEnvironment);
    await tester.tap(skipEnvironment);
    await tester.pumpAndSettle();

    final providerNext = find.byKey(const ValueKey('tutorial-provider-next'));
    await showFinder(tester, providerNext);
    await tester.tap(providerNext);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tutorial-provider-api-key')),
      'sk-test',
    );
    final connect = find.byKey(const ValueKey('tutorial-provider-connect'));
    await showFinder(tester, connect);
    await tester.tap(connect);
    await tester.pumpAndSettle();

    expect(find.text('已准备 2 个模型'), findsOneWidget);
    expect(find.text('确认可用模型'), findsOneWidget);

    final modelsNext = find.byKey(const ValueKey('tutorial-models-next'));
    await showFinder(tester, modelsNext);
    await tester.tap(modelsNext);
    await tester.pumpAndSettle();

    expect(find.text('配置对话与 Agent 模型'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tutorial-scene-scene.dispatch.model')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tutorial-scene-scene.memory.embedding')),
      findsNothing,
    );

    final primaryScenesNext = find.byKey(
      const ValueKey('tutorial-primary-scenes-next'),
    );
    await showFinder(tester, primaryScenesNext);
    await tester.tap(primaryScenesNext);
    await tester.pumpAndSettle();

    expect(find.text('配置记忆模型'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tutorial-scene-scene.memory.embedding')),
      findsOneWidget,
    );

    final saveScenes = find.byKey(const ValueKey('tutorial-save-scenes'));
    await showFinder(tester, saveScenes);
    await tester.tap(saveScenes);
    for (var frame = 0; frame < 15; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-spotlight-tour')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-spotlight-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-spotlight-next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-spotlight-back')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsNothing);
    expect(find.text('配置记忆模型'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
