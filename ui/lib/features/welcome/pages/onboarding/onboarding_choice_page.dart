import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/constants/storage_keys.dart';
import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/features/home/pages/chat/chat_page.dart';
import 'package:ui/services/model_provider_config_service.dart';
import 'package:ui/services/model_vendor_catalog.dart';
import 'package:ui/services/scene_model_config_service.dart';
import 'package:ui/services/special_permission.dart';
import 'package:ui/services/storage_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/provider_vendor_icon.dart';

enum _TutorialPage {
  system,
  development,
  tools,
  environmentProgress,
  provider,
  providerConnection,
  modelInventory,
  primaryScenes,
  memoryScenes,
  completion,
}

const List<_TutorialPage> _tutorialNavigationPages = <_TutorialPage>[
  _TutorialPage.system,
  _TutorialPage.development,
  _TutorialPage.tools,
  _TutorialPage.provider,
  _TutorialPage.providerConnection,
  _TutorialPage.modelInventory,
  _TutorialPage.primaryScenes,
  _TutorialPage.memoryScenes,
];

class _EnvironmentPreset {
  const _EnvironmentPreset({
    required this.id,
    required this.icon,
    required this.titleZh,
    required this.titleEn,
    required this.descriptionZh,
    required this.descriptionEn,
    required this.packageIds,
    required this.contents,
  });

  final String id;
  final IconData icon;
  final String titleZh;
  final String titleEn;
  final String descriptionZh;
  final String descriptionEn;
  final List<String> packageIds;
  final String contents;
}

class _OptionalTool {
  const _OptionalTool({
    required this.id,
    required this.icon,
    required this.label,
    required this.descriptionZh,
    required this.descriptionEn,
  });

  final String id;
  final IconData icon;
  final String label;
  final String descriptionZh;
  final String descriptionEn;
}

class _ProviderOption {
  const _ProviderOption({
    required this.id,
    required this.label,
    required this.vendorKey,
    required this.baseUrl,
    required this.sourceType,
    required this.protocolType,
  });

  final String id;
  final String label;
  final String? vendorKey;
  final String baseUrl;
  final String sourceType;
  final String protocolType;
}

class _SceneDefinition {
  const _SceneDefinition({
    required this.id,
    required this.icon,
    required this.title,
    required this.descriptionZh,
    required this.descriptionEn,
  });

  final String id;
  final IconData icon;
  final String title;
  final String descriptionZh;
  final String descriptionEn;
}

const List<_EnvironmentPreset> _environmentPresets = <_EnvironmentPreset>[
  _EnvironmentPreset(
    id: 'general',
    icon: LucideIcons.layers3,
    titleZh: '通用开发',
    titleEn: 'General development',
    descriptionZh: '适合大多数项目，一次准备 Web、脚本和版本管理工具。',
    descriptionEn:
        'A balanced setup for web projects, scripts, and version control.',
    packageIds: <String>['nodejs', 'npm', 'git', 'python', 'pip', 'uv'],
    contents: 'Node.js · npm · Python · pip · uv · Git',
  ),
  _EnvironmentPreset(
    id: 'node',
    icon: LucideIcons.braces,
    titleZh: 'Node.js / Web',
    titleEn: 'Node.js / Web',
    descriptionZh: '面向前端、后端服务和 JavaScript / TypeScript 工程。',
    descriptionEn:
        'For frontend, backend services, and JavaScript or TypeScript projects.',
    packageIds: <String>['nodejs', 'npm', 'git'],
    contents: 'Node.js · npm · Git',
  ),
  _EnvironmentPreset(
    id: 'python',
    icon: LucideIcons.code2,
    titleZh: 'Python',
    titleEn: 'Python',
    descriptionZh: '面向自动化、数据处理、脚本和 Python 项目。',
    descriptionEn:
        'For automation, data processing, scripts, and Python projects.',
    packageIds: <String>['python', 'pip', 'uv', 'git'],
    contents: 'Python · pip · uv · Git',
  ),
];

const List<_OptionalTool> _optionalTools = <_OptionalTool>[
  _OptionalTool(
    id: 'codex',
    icon: LucideIcons.bot,
    label: 'Codex CLI',
    descriptionZh: 'OpenAI 编程 Agent',
    descriptionEn: 'OpenAI coding agent',
  ),
  _OptionalTool(
    id: 'claude_code',
    icon: LucideIcons.sparkles,
    label: 'Claude Code',
    descriptionZh: 'Anthropic 编程 Agent',
    descriptionEn: 'Anthropic coding agent',
  ),
  _OptionalTool(
    id: 'opencode',
    icon: LucideIcons.squareTerminal,
    label: 'OpenCode',
    descriptionZh: '开源编程 Agent',
    descriptionEn: 'Open-source coding agent',
  ),
  _OptionalTool(
    id: 'ssh_client',
    icon: LucideIcons.server,
    label: 'SSH',
    descriptionZh: '连接远程开发主机',
    descriptionEn: 'Connect to remote hosts',
  ),
];

const List<_ProviderOption> _providerOptions = <_ProviderOption>[
  _ProviderOption(
    id: 'deepseek',
    label: 'DeepSeek',
    vendorKey: 'deepseek',
    baseUrl: 'https://api.deepseek.com',
    sourceType: 'deepseek',
    protocolType: 'deepseek',
  ),
  _ProviderOption(
    id: 'moonshot',
    label: 'Kimi',
    vendorKey: 'moonshot',
    baseUrl: 'https://api.moonshot.cn/v1',
    sourceType: 'moonshot',
    protocolType: 'openai_compatible',
  ),
  _ProviderOption(
    id: 'mimo',
    label: 'Mimo',
    vendorKey: 'xiaomi',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    sourceType: 'mimo',
    protocolType: 'openai_compatible',
  ),
  _ProviderOption(
    id: 'openai',
    label: 'OpenAI',
    vendorKey: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    sourceType: 'custom',
    protocolType: 'openai_compatible',
  ),
  _ProviderOption(
    id: 'anthropic',
    label: 'Anthropic',
    vendorKey: 'anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    sourceType: 'custom',
    protocolType: 'anthropic',
  ),
  _ProviderOption(
    id: 'custom',
    label: 'Compatible API',
    vendorKey: null,
    baseUrl: '',
    sourceType: 'custom',
    protocolType: 'openai_compatible',
  ),
];

const List<_SceneDefinition> _sceneDefinitions = <_SceneDefinition>[
  _SceneDefinition(
    id: 'scene.dispatch.model',
    icon: LucideIcons.bot,
    title: 'Agent',
    descriptionZh: '理解任务、规划步骤并调用工具，建议选择能力最强的工具调用模型。',
    descriptionEn:
        'Understands tasks, plans work, and calls tools. Prefer your strongest tool-capable model.',
  ),
  _SceneDefinition(
    id: 'scene.voice',
    icon: LucideIcons.mic2,
    title: 'Voice',
    descriptionZh: '整理适合朗读的回复文本，建议选择响应快、中文自然的模型。',
    descriptionEn:
        'Prepares responses for speech. Prefer a fast model with natural language output.',
  ),
  _SceneDefinition(
    id: 'scene.compactor.context.chat',
    icon: LucideIcons.messagesSquare,
    title: 'Chat Compactor',
    descriptionZh: '在长对话中压缩历史上下文，平衡速度与总结准确度。',
    descriptionEn:
        'Compresses long chat history while balancing speed and summary accuracy.',
  ),
  _SceneDefinition(
    id: 'scene.memory.embedding',
    icon: LucideIcons.database,
    title: 'Memory Embed',
    descriptionZh: '把记忆转换为向量用于检索；若提供商有 embedding 模型，请优先选择。',
    descriptionEn:
        'Creates vectors for memory search. Prefer an embedding model when available.',
  ),
  _SceneDefinition(
    id: 'scene.memory.rollup',
    icon: LucideIcons.memoryStick,
    title: 'Memory Rollup',
    descriptionZh: '归纳长期记忆并去除重复信息，适合稳定、成本适中的文本模型。',
    descriptionEn:
        'Consolidates long-term memory and removes duplicates. A reliable text model is ideal.',
  ),
];

class OnboardingChoicePage extends StatefulWidget {
  const OnboardingChoicePage({super.key});

  @override
  State<OnboardingChoicePage> createState() => _OnboardingChoicePageState();
}

class _OnboardingChoicePageState extends State<OnboardingChoicePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _manualModelController = TextEditingController();

  StreamSubscription<EmbeddedTerminalInitProgress>?
  _terminalProgressSubscription;
  Timer? _environmentProgressTimer;

  _TutorialPage _page = _TutorialPage.system;
  final List<_TutorialPage> _pageHistory = <_TutorialPage>[];
  final Set<_TutorialPage> _visitedTutorialPages = <_TutorialPage>{
    _TutorialPage.system,
  };
  double _horizontalDragDistance = 0;
  EmbeddedTerminalDistribution _distribution =
      EmbeddedTerminalDistribution.alpine;
  String _environmentPresetId = 'general';
  Set<String> _optionalToolIds = <String>{};
  bool _isReplay = false;
  bool _isDistributionLoading = true;
  bool _isEnvironmentBusy = false;
  bool _environmentReady = false;
  bool _environmentFailed = false;
  double _environmentProgress = 0;
  double _environmentNativeProgress = 0;
  String _environmentStage = '';
  bool _environmentSnapshotLoading = false;

  bool _providerDataLoaded = false;
  bool _providerLoading = false;
  bool _providerBusy = false;
  bool _providerConnected = false;
  bool _obscureApiKey = true;
  String _selectedProviderId = 'deepseek';
  String? _providerError;
  ModelProviderProfileSummary? _activeProfile;
  List<ModelProviderProfileSummary> _profiles = const [];
  List<ProviderModelOption> _modelOptions = const [];
  Map<String, String> _sceneModelSelections = <String, String>{};
  Set<String> _savingSceneIds = <String>{};
  bool _sceneModelsSaving = false;
  bool _isCompletingTutorial = false;

  bool get _isEnglish =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'en';

  String _t(String zh, String en) => _isEnglish ? en : zh;

  _EnvironmentPreset get _selectedEnvironmentPreset =>
      _environmentPresets.firstWhere((item) => item.id == _environmentPresetId);

  _ProviderOption get _selectedProvider =>
      _providerOptions.firstWhere((item) => item.id == _selectedProviderId);

  List<String> get _selectedPackageIds => <String>{
    ..._selectedEnvironmentPreset.packageIds,
    ..._optionalToolIds,
  }.toList(growable: false);

  @override
  void initState() {
    super.initState();
    _isReplay =
        StorageService.getBool(
          StorageKeys.welcomeCompleted,
          defaultValue: false,
        ) ??
        false;
    _applyProviderOption(_providerOptions.first, notify: false);
    _terminalProgressSubscription = embeddedTerminalInitProgressStream.listen(
      (_) => unawaited(_reloadEnvironmentSnapshot()),
      onError: (_) {},
    );
    unawaited(_loadDistribution());
  }

  @override
  void dispose() {
    _terminalProgressSubscription?.cancel();
    _environmentProgressTimer?.cancel();
    _scrollController.dispose();
    _providerNameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _manualModelController.dispose();
    super.dispose();
  }

  Future<void> _loadDistribution() async {
    try {
      final distribution = await getEmbeddedTerminalDistribution();
      if (!mounted) return;
      setState(() => _distribution = distribution);
    } catch (_) {
      // Alpine remains the safe visible default when the native channel is
      // unavailable in widget tests or unsupported builds.
    } finally {
      if (mounted) {
        setState(() => _isDistributionLoading = false);
      }
    }
  }

  Future<void> _reloadEnvironmentSnapshot() async {
    if (_environmentSnapshotLoading) return;
    _environmentSnapshotLoading = true;
    try {
      final snapshot = await getEmbeddedTerminalInitSnapshot();
      if (!mounted || !_isEnvironmentBusy) return;
      if (!snapshot.running) return;
      setState(() {
        _environmentNativeProgress = snapshot.progress;
        if (snapshot.stage.trim().isNotEmpty) {
          _environmentStage = snapshot.stage.trim();
        }
      });
    } catch (_) {
    } finally {
      _environmentSnapshotLoading = false;
    }
  }

  void _startEnvironmentProgressTracking() {
    _environmentProgressTimer?.cancel();
    _environmentProgressTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) {
        if (!mounted || !_isEnvironmentBusy) {
          _environmentProgressTimer?.cancel();
          return;
        }
        unawaited(_reloadEnvironmentSnapshot());
        final stageFloor = _environmentProgressFloor(_environmentStage);
        final stageCeiling = _environmentProgressCeiling(
          _environmentStage,
        ).clamp(_environmentProgress, 0.99);
        final requiredTarget = [
          _environmentNativeProgress,
          stageFloor,
        ].reduce((left, right) => left > right ? left : right);
        final current = _environmentProgress;
        double next;
        if (current + 0.001 < requiredTarget) {
          final distance = requiredTarget - current;
          next = current + (distance * 0.24).clamp(0.008, 0.035);
        } else {
          final remaining = stageCeiling - current;
          next = remaining <= 0
              ? current
              : current + (remaining * 0.018).clamp(0.0006, 0.004);
        }
        next = next.clamp(current, stageCeiling);
        if ((next - current).abs() >= 0.0001) {
          setState(() => _environmentProgress = next);
        }
      },
    );
  }

  double _environmentProgressFloor(String stage) {
    final phase = _environmentPhaseIndex(stage);
    return switch (phase) {
      0 => 0.03,
      1 => 0.10,
      2 => 0.54,
      3 => 0.90,
      _ => 0.99,
    };
  }

  double _environmentProgressCeiling(String stage) {
    final phase = _environmentPhaseIndex(stage);
    return switch (phase) {
      0 => 0.09,
      1 => 0.50,
      2 => 0.89,
      3 => 0.98,
      _ => 0.99,
    };
  }

  int _environmentPhaseIndex(String stage) {
    final normalized = stage.trim();
    if (_environmentReady ||
        normalized.contains('配置完成') ||
        normalized.contains('均已就绪') ||
        normalized.contains('所选开发工具已就绪')) {
      return 4;
    }
    var phase = 0;
    if (normalized.contains('验证') ||
        normalized.contains('安装完成') ||
        normalized.contains('校验完成')) {
      phase = 3;
    } else if (normalized.contains('所选开发工具') ||
        normalized.contains('Agent CLI 包')) {
      phase = 2;
    } else if (normalized.contains('workspace') ||
        normalized.contains('终端') ||
        normalized.contains('Linux') ||
        normalized.contains('Alpine') ||
        normalized.contains('Ubuntu') ||
        normalized.contains('运行资源')) {
      phase = 1;
    }
    final knownProgress = _environmentNativeProgress > _environmentProgress
        ? _environmentNativeProgress
        : _environmentProgress;
    final progressPhase = knownProgress >= 0.90
        ? 3
        : knownProgress >= 0.54
        ? 2
        : knownProgress >= 0.10
        ? 1
        : 0;
    return phase > progressPhase ? phase : progressPhase;
  }

  Future<void> _completeEnvironmentProgressAnimation() async {
    _environmentProgressTimer?.cancel();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (mounted) setState(() => _environmentProgress = 1);
      return;
    }
    final start = _environmentProgress;
    for (var frame = 1; frame <= 12; frame++) {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      if (!mounted) return;
      final t = frame / 12;
      final eased = 1 - (1 - t) * (1 - t);
      setState(() {
        _environmentProgress = start + (1 - start) * eased;
      });
    }
  }

  Future<void> _startEnvironmentSetup() async {
    if (_isEnvironmentBusy || _isDistributionLoading) return;
    setState(() {
      if (_page != _TutorialPage.environmentProgress) {
        _pageHistory.add(_page);
        _page = _TutorialPage.environmentProgress;
      }
      _isEnvironmentBusy = true;
      _environmentReady = false;
      _environmentFailed = false;
      _environmentProgress = 0.02;
      _environmentNativeProgress = 0.02;
      _environmentStage = _t('正在保存你的选择…', 'Saving your choices…');
    });
    _startEnvironmentProgressTracking();

    try {
      final saved = await setEmbeddedTerminalDistribution(_distribution);
      if (!mounted) return;
      setState(() {
        _distribution = saved;
        _environmentStage = _t(
          '正在准备 ${saved == EmbeddedTerminalDistribution.ubuntu ? 'Ubuntu' : 'Alpine'} 系统…',
          'Preparing ${saved == EmbeddedTerminalDistribution.ubuntu ? 'Ubuntu' : 'Alpine'}…',
        );
      });
      final result = await prepareTermuxLiveWrapper(
        packageIds: _selectedPackageIds,
      );
      if (!mounted) return;
      await _reloadEnvironmentSnapshot();
      final success = result['success'] == true;
      if (success) {
        await _completeEnvironmentProgressAnimation();
      } else {
        _environmentProgressTimer?.cancel();
      }
      if (!mounted) return;
      setState(() {
        _isEnvironmentBusy = false;
        _environmentReady = success;
        _environmentFailed = !success;
        if (success) {
          _environmentProgress = 1;
          _environmentStage = _t(
            '系统与开发环境已准备完成',
            'System and development environment are ready',
          );
        } else {
          _environmentStage =
              (result['message'] ?? '').toString().trim().isNotEmpty
              ? (result['message'] ?? '').toString().trim()
              : _t('配置未完成，请重试', 'Setup did not finish. Please retry.');
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      _environmentProgressTimer?.cancel();
      setState(() {
        _isEnvironmentBusy = false;
        _environmentFailed = true;
        _environmentStage =
            error.message ?? _t('配置失败，请重试', 'Setup failed. Please retry.');
      });
    } catch (error) {
      if (!mounted) return;
      _environmentProgressTimer?.cancel();
      setState(() {
        _isEnvironmentBusy = false;
        _environmentFailed = true;
        _environmentStage = _t('配置失败：$error', 'Setup failed: $error');
      });
    }
  }

  void _selectDistribution(EmbeddedTerminalDistribution value) {
    if (_isEnvironmentBusy || _distribution == value) return;
    setState(() {
      _distribution = value;
      _environmentReady = false;
      _environmentFailed = false;
      _environmentProgress = 0;
    });
  }

  void _selectEnvironmentPreset(String id) {
    if (_isEnvironmentBusy || _environmentPresetId == id) return;
    setState(() {
      _environmentPresetId = id;
      _environmentReady = false;
      _environmentFailed = false;
      _environmentProgress = 0;
    });
  }

  void _toggleOptionalTool(String id) {
    if (_isEnvironmentBusy) return;
    setState(() {
      if (_optionalToolIds.contains(id)) {
        _optionalToolIds = <String>{..._optionalToolIds}..remove(id);
      } else {
        _optionalToolIds = <String>{..._optionalToolIds, id};
      }
      _environmentReady = false;
      _environmentFailed = false;
      _environmentProgress = 0;
    });
  }

  void _goToPage(_TutorialPage page) {
    if (_page == page) return;
    final targetIndex = _tutorialNavigationPages.indexOf(page);
    setState(() {
      _pageHistory.add(_page);
      _page = page;
      if (targetIndex >= 0) {
        _visitedTutorialPages.add(page);
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (page == _TutorialPage.provider) {
      unawaited(_loadProviderData());
    }
  }

  Future<void> _openChatTour() async {
    if (!mounted) return;
    final tourCompleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ChatPage(showFirstUseTour: true),
        settings: const RouteSettings(name: 'first-use-chat-spotlight-tour'),
      ),
    );
    if (tourCompleted == true && mounted) {
      _goToPage(_TutorialPage.completion);
    }
  }

  Future<void> _startExploring() async {
    if (_isCompletingTutorial) return;
    setState(() => _isCompletingTutorial = true);
    await StorageService.setBool(StorageKeys.welcomeCompleted, true);
    if (!mounted) return;
    setState(() => _isCompletingTutorial = false);
    GoRouterManager.clearAndNavigateTo('/home/chat');
  }

  Future<void> _loadProviderData() async {
    if (_providerDataLoaded || _providerLoading) return;
    setState(() => _providerLoading = true);
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        ModelProviderConfigService.listProfiles(),
        SceneModelConfigService.getSceneModelBindings(),
      ]);
      if (!mounted) return;
      final payload = results[0] as ModelProviderProfilesPayload;
      final bindings = results[1] as List<SceneModelBindingEntry>;
      final configuredProfiles = payload.profiles
          .where((profile) => profile.configured)
          .toList(growable: false);
      ModelProviderProfileSummary? profile;
      if (configuredProfiles.isNotEmpty) {
        profile = configuredProfiles.firstWhere(
          (item) => item.id == payload.editingProfileId,
          orElse: () => configuredProfiles.first,
        );
      }

      var models = const <ProviderModelOption>[];
      if (profile != null) {
        models =
            await ModelProviderConfigService.getStoredModelOptionsForProfile(
              profile.id,
              profile: profile,
              enrichMetadata: false,
            );
      }
      if (!mounted) return;
      setState(() {
        _providerDataLoaded = true;
        _profiles = payload.profiles;
        if (profile != null) {
          _activeProfile = profile;
          _providerConnected = true;
          _modelOptions = models;
          _applyExistingProfile(profile);
          _applyDefaultSceneSelections(bindings: bindings);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _providerDataLoaded = true;
        _providerError = _t(
          '暂时无法读取已有配置，你仍可创建新的模型连接。',
          'Existing settings could not be loaded. You can still create a new connection.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _providerLoading = false);
      }
    }
  }

  void _applyExistingProfile(ModelProviderProfileSummary profile) {
    final matching = _providerOptions.where((option) {
      if (option.id == 'custom') return false;
      if (option.sourceType != 'custom' &&
          profile.sourceType == option.sourceType) {
        return true;
      }
      final normalizedProfileBase =
          ModelProviderConfigService.normalizeApiBase(profile.baseUrl) ?? '';
      final normalizedOptionBase =
          ModelProviderConfigService.normalizeApiBase(option.baseUrl) ?? '';
      return normalizedOptionBase.isNotEmpty &&
          normalizedProfileBase == normalizedOptionBase;
    });
    final option = matching.isEmpty ? _providerOptions.last : matching.first;
    _selectedProviderId = option.id;
    _providerNameController.text = profile.name;
    _baseUrlController.text = profile.baseUrl;
    _apiKeyController.text = profile.apiKey;
  }

  void _applyProviderOption(_ProviderOption option, {bool notify = true}) {
    void apply() {
      _selectedProviderId = option.id;
      _providerNameController.text = option.id == 'custom' ? '' : option.label;
      _baseUrlController.text = option.baseUrl;
      _apiKeyController.clear();
      _activeProfile = null;
      _providerConnected = false;
      _modelOptions = const [];
      _sceneModelSelections = <String, String>{};
      _providerError = null;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _configureProvider() async {
    if (_providerBusy) return;
    final option = _selectedProvider;
    final name = _providerNameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _providerError = _t('请填写提供商名称。', 'Enter a provider name.');
      });
      return;
    }
    if (!ModelProviderConfigService.isValidApiBase(baseUrl)) {
      setState(() {
        _providerError = _t(
          '请输入有效的 HTTPS API 地址。',
          'Enter a valid HTTPS API base URL.',
        );
      });
      return;
    }
    if (option.id != 'custom' && apiKey.isEmpty) {
      setState(() {
        _providerError = _t(
          '此提供商需要 API Key。',
          'This provider requires an API key.',
        );
      });
      return;
    }

    setState(() {
      _providerBusy = true;
      _providerError = null;
    });
    try {
      final normalizedBase =
          ModelProviderConfigService.normalizeApiBase(baseUrl) ?? '';
      final existing = _profiles.where((profile) {
        final profileBase =
            ModelProviderConfigService.normalizeApiBase(profile.baseUrl) ?? '';
        if (option.sourceType != 'custom') {
          return profile.sourceType == option.sourceType;
        }
        return profileBase.isNotEmpty && profileBase == normalizedBase;
      });
      final saved = await ModelProviderConfigService.saveProfile(
        id: existing.isEmpty ? null : existing.first.id,
        name: name,
        baseUrl: baseUrl,
        apiKey: apiKey,
        sourceType: option.sourceType,
        protocolType: option.protocolType,
        wireApi: 'chat_completions',
      );
      List<ProviderModelOption> models = const [];
      String? fetchError;
      try {
        models = await ModelProviderConfigService.fetchModels(
          apiBase: baseUrl,
          apiKey: apiKey,
          profileId: saved.id,
          providerName: saved.name,
        );
        if (models.isEmpty) {
          fetchError = _t(
            '连接已保存，但没有读取到模型。你可以在下方手动添加模型 ID。',
            'The connection was saved, but no models were returned. Add a model ID below.',
          );
        }
      } catch (error) {
        fetchError = _t(
          '连接已保存，但模型列表读取失败。请检查地址与密钥，或手动添加模型 ID。',
          'The connection was saved, but models could not be fetched. Check the URL and key, or add a model ID.',
        );
      }
      if (!mounted) return;
      setState(() {
        _activeProfile = saved;
        _profiles = <ModelProviderProfileSummary>[
          ..._profiles.where((profile) => profile.id != saved.id),
          saved,
        ];
        _providerConnected = true;
        _modelOptions = models;
        _providerError = fetchError;
        _applyDefaultSceneSelections();
      });
      _goToPage(_TutorialPage.modelInventory);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _providerError = _t(
          '无法保存模型提供商：$error',
          'Could not save the model provider: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _providerBusy = false);
      }
    }
  }

  void _applyDefaultSceneSelections({
    List<SceneModelBindingEntry> bindings = const [],
  }) {
    if (_modelOptions.isEmpty) {
      _sceneModelSelections = <String, String>{};
      return;
    }
    final bindingMap = <String, SceneModelBindingEntry>{
      for (final binding in bindings) binding.sceneId: binding,
    };
    final firstGeneral = _modelOptions.firstWhere(
      (model) => !_looksLikeEmbeddingModel(model.id),
      orElse: () => _modelOptions.first,
    );
    final firstEmbedding = _modelOptions.firstWhere(
      (model) => _looksLikeEmbeddingModel(model.id),
      orElse: () => firstGeneral,
    );
    _sceneModelSelections = <String, String>{
      for (final scene in _sceneDefinitions)
        scene.id: () {
          final boundModelId = bindingMap[scene.id]?.modelId;
          if (boundModelId != null &&
              _modelOptions.any((model) => model.id == boundModelId)) {
            return boundModelId;
          }
          return scene.id == 'scene.memory.embedding'
              ? firstEmbedding.id
              : firstGeneral.id;
        }(),
    };
  }

  bool _looksLikeEmbeddingModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('embed') ||
        normalized.contains('bge-') ||
        normalized.contains('text-embedding');
  }

  Future<void> _addManualModel() async {
    final profile = _activeProfile;
    final modelId = _manualModelController.text.trim();
    if (profile == null || modelId.isEmpty) return;
    if (!ModelProviderConfigService.isValidModelName(modelId)) {
      setState(() {
        _providerError = _t(
          '模型 ID 格式无效，请检查空格或特殊字符。',
          'The model ID is invalid. Check spaces and special characters.',
        );
      });
      return;
    }
    if (_modelOptions.any((model) => model.id == modelId)) {
      _manualModelController.clear();
      return;
    }
    try {
      final currentIds = await ModelProviderConfigService.getManualModelIds(
        profileId: profile.id,
      );
      await ModelProviderConfigService.saveManualModelIds(
        profileId: profile.id,
        ids: <String>[...currentIds, modelId],
      );
      if (!mounted) return;
      setState(() {
        _modelOptions = <ProviderModelOption>[
          ..._modelOptions,
          ProviderModelOption(
            id: modelId,
            displayName: modelId,
            ownedBy: 'manual',
          ),
        ];
        _manualModelController.clear();
        _providerError = null;
        _applyDefaultSceneSelections();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _providerError = _t('无法添加模型：$error', 'Could not add the model: $error');
      });
    }
  }

  Future<void> _saveSceneModels() async {
    final profile = _activeProfile;
    if (profile == null || _modelOptions.isEmpty || _sceneModelsSaving) return;
    final missingScene = _sceneDefinitions.any(
      (scene) => (_sceneModelSelections[scene.id] ?? '').trim().isEmpty,
    );
    if (missingScene) {
      setState(() {
        _providerError = _t('请为每个场景选择模型。', 'Choose a model for every scene.');
      });
      return;
    }

    setState(() {
      _sceneModelsSaving = true;
      _providerError = null;
    });
    var saved = false;
    try {
      for (final scene in _sceneDefinitions) {
        if (!mounted) return;
        setState(() {
          _savingSceneIds = <String>{..._savingSceneIds, scene.id};
        });
        await SceneModelConfigService.saveSceneModelBinding(
          sceneId: scene.id,
          providerProfileId: profile.id,
          modelId: _sceneModelSelections[scene.id]!,
        );
        if (!mounted) return;
        setState(() {
          _savingSceneIds = <String>{..._savingSceneIds}..remove(scene.id);
        });
      }
      saved = true;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _providerError = _t(
          '场景模型保存失败：$error',
          'Scene model setup failed: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _sceneModelsSaving = false;
          _savingSceneIds = <String>{};
        });
      }
    }
    if (saved && mounted) {
      await _openChatTour();
    }
  }

  void _handleBack() {
    if (_isEnvironmentBusy || _providerBusy || _sceneModelsSaving) return;
    if (_pageHistory.isNotEmpty) {
      setState(() {
        _page = _pageHistory.removeLast();
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }
    if (_isReplay) {
      Navigator.of(context).maybePop();
    }
  }

  bool get _isTutorialNavigationPage =>
      _tutorialNavigationPages.contains(_page);

  VoidCallback? get _tutorialNextAction {
    return switch (_page) {
      _TutorialPage.system when !_isDistributionLoading => () => _goToPage(
        _TutorialPage.development,
      ),
      _TutorialPage.development => () => _goToPage(_TutorialPage.tools),
      _TutorialPage.tools => () => _goToPage(_TutorialPage.provider),
      _TutorialPage.provider => () => unawaited(_openChatTour()),
      _TutorialPage.providerConnection when _providerConnected =>
        () => _goToPage(_TutorialPage.modelInventory),
      _TutorialPage.modelInventory when _modelOptions.isNotEmpty =>
        () => _goToPage(_TutorialPage.primaryScenes),
      _TutorialPage.primaryScenes when _modelOptions.isNotEmpty =>
        () => _goToPage(_TutorialPage.memoryScenes),
      _ => null,
    };
  }

  String get _tutorialNextTooltip {
    return switch (_page) {
      _TutorialPage.tools => _t('暂不配置环境，先设置模型', 'Set up the environment later'),
      _TutorialPage.provider => _t(
        '暂不配置模型，先了解聊天界面',
        'Learn the chat interface first',
      ),
      _ =>
        _tutorialNextAction == null
            ? _t('请先完成本页操作', 'Complete this page first')
            : _t('下一步', 'Next'),
    };
  }

  Key get _tutorialNextKey {
    return switch (_page) {
      _TutorialPage.system => const ValueKey('tutorial-system-next'),
      _TutorialPage.development => const ValueKey('tutorial-development-next'),
      _TutorialPage.tools => const ValueKey('tutorial-skip-environment'),
      _TutorialPage.provider => const ValueKey('tutorial-skip-models'),
      _TutorialPage.modelInventory => const ValueKey('tutorial-models-next'),
      _TutorialPage.primaryScenes => const ValueKey(
        'tutorial-primary-scenes-next',
      ),
      _ => const ValueKey('tutorial-page-next'),
    };
  }

  void _goToNextTutorialPage() {
    _tutorialNextAction?.call();
  }

  void _jumpToVisitedTutorialPage(_TutorialPage page) {
    if (page == _page || !_visitedTutorialPages.contains(page)) return;
    final historyIndex = _pageHistory.lastIndexOf(page);
    if (historyIndex < 0) {
      _goToPage(page);
      return;
    }
    setState(() {
      _pageHistory.removeRange(historyIndex, _pageHistory.length);
      _page = page;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (page == _TutorialPage.provider) {
      unawaited(_loadProviderData());
    }
  }

  void _handleTutorialDragStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _handleTutorialDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleTutorialDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final direction = _horizontalDragDistance.abs() >= 64
        ? _horizontalDragDistance
        : velocity.abs() >= 260
        ? velocity
        : 0;
    _horizontalDragDistance = 0;
    if (direction < 0) {
      _goToNextTutorialPage();
    } else if (direction > 0 && _showBottomBack) {
      _handleBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final canPop = _pageHistory.isEmpty && _isReplay;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (_pageHistory.isNotEmpty || _isReplay)) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('tutorial-page-swipe-surface'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _isTutorialNavigationPage
                      ? _handleTutorialDragStart
                      : null,
                  onHorizontalDragUpdate: _isTutorialNavigationPage
                      ? _handleTutorialDragUpdate
                      : null,
                  onHorizontalDragEnd: _isTutorialNavigationPage
                      ? _handleTutorialDragEnd
                      : null,
                  child: AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: KeyedSubtree(
                      key: ValueKey<_TutorialPage>(_page),
                      child: switch (_page) {
                        _TutorialPage.system => _buildSystemPage(),
                        _TutorialPage.development => _buildDevelopmentPage(),
                        _TutorialPage.tools => _buildToolsPage(),
                        _TutorialPage.environmentProgress =>
                          _buildEnvironmentProgressPage(),
                        _TutorialPage.provider => _buildProviderPage(),
                        _TutorialPage.providerConnection =>
                          _buildProviderConnectionPage(),
                        _TutorialPage.modelInventory =>
                          _buildModelInventoryPage(),
                        _TutorialPage.primaryScenes =>
                          _buildPrimaryScenesPage(),
                        _TutorialPage.memoryScenes => _buildMemoryScenesPage(),
                        _TutorialPage.completion => _buildCompletionPage(),
                      },
                    ),
                  ),
                ),
              ),
              if (_isTutorialNavigationPage) _buildTutorialFooter(),
              if (_page == _TutorialPage.completion) _buildCompletionFooter(),
            ],
          ),
        ),
      ),
    );
  }

  bool get _showBottomBack => _pageHistory.isNotEmpty || _isReplay;

  Widget _buildTutorialFooter() {
    final primaryAction = _buildTutorialPrimaryAction();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Column(
            key: const ValueKey('tutorial-fixed-footer'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (primaryAction != null) ...[
                KeyedSubtree(
                  key: const ValueKey('tutorial-sticky-primary-action'),
                  child: primaryAction,
                ),
                const SizedBox(height: 6),
              ],
              _buildTutorialNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionFooter() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: SizedBox(
            key: const ValueKey('tutorial-completion-footer'),
            height: 58,
            child: Row(
              children: [
                _buildTutorialArrow(
                  key: const ValueKey('tutorial-bottom-back'),
                  icon: LucideIcons.arrowLeft,
                  tooltip: _t('返回上一步', 'Back'),
                  onPressed: _isCompletingTutorial ? null : _handleBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrimaryButton(
                    key: const ValueKey('tutorial-start-exploring'),
                    label: _isCompletingTutorial
                        ? _t('正在进入…', 'Opening…')
                        : _t('开始探索', 'Start exploring'),
                    icon: LucideIcons.rocket,
                    onPressed: _isCompletingTutorial ? null : _startExploring,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildTutorialPrimaryAction() {
    return switch (_page) {
      _TutorialPage.tools => _buildPrimaryButton(
        key: const ValueKey('tutorial-environment-primary'),
        label: _t('开始配置', 'Start setup'),
        icon: LucideIcons.download,
        onPressed: _isDistributionLoading ? null : _startEnvironmentSetup,
      ),
      _TutorialPage.provider => _buildPrimaryButton(
        key: const ValueKey('tutorial-provider-next'),
        label: _t('继续填写连接信息', 'Continue to connection details'),
        icon: LucideIcons.arrowRight,
        onPressed: _providerLoading
            ? null
            : () => _goToPage(_TutorialPage.providerConnection),
      ),
      _TutorialPage.providerConnection => _buildPrimaryButton(
        key: const ValueKey('tutorial-provider-connect'),
        label: _providerBusy
            ? _t('正在连接并读取模型…', 'Connecting and fetching models…')
            : _providerConnected
            ? _t('重新连接并读取模型', 'Reconnect and fetch models')
            : _t('连接并读取模型', 'Connect and fetch models'),
        icon: _providerConnected ? LucideIcons.refreshCw : LucideIcons.plugZap,
        onPressed: _providerBusy ? null : _configureProvider,
      ),
      _TutorialPage.memoryScenes => _buildPrimaryButton(
        key: const ValueKey('tutorial-save-scenes'),
        label: _sceneModelsSaving
            ? _t('正在保存场景配置…', 'Saving model roles…')
            : _t('保存并了解聊天界面', 'Save and learn the chat interface'),
        icon: LucideIcons.arrowRight,
        onPressed:
            _sceneModelsSaving ||
                _activeProfile == null ||
                _modelOptions.isEmpty
            ? null
            : _saveSceneModels,
      ),
      _ => null,
    };
  }

  Widget _buildTutorialNavigation() {
    final palette = context.omniPalette;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final currentIndex = _tutorialNavigationPages.indexOf(_page);
    final canGoBack = _showBottomBack;
    final nextAction = _tutorialNextAction;

    return SizedBox(
      key: const ValueKey('tutorial-pagination-navigation'),
      height: 58,
      child: Row(
        children: [
          _buildTutorialArrow(
            key: const ValueKey('tutorial-bottom-back'),
            icon: LucideIcons.arrowLeft,
            tooltip: _t('上一步', 'Previous'),
            onPressed: canGoBack ? _handleBack : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_tutorialNavigationPages.length, (
                index,
              ) {
                final page = _tutorialNavigationPages[index];
                final selected = index == currentIndex;
                final visited = _visitedTutorialPages.contains(page);
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    enabled: visited,
                    label: _t(
                      '教程第 ${index + 1} 页',
                      'Tutorial page ${index + 1}',
                    ),
                    child: InkResponse(
                      key: ValueKey<String>('tutorial-page-dot-$index'),
                      onTap: visited
                          ? () => _jumpToVisitedTutorialPage(page)
                          : null,
                      radius: 22,
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: AnimatedContainer(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            width: selected ? 9 : 6,
                            height: selected ? 9 : 6,
                            decoration: BoxDecoration(
                              color: selected
                                  ? palette.accentPrimary
                                  : visited
                                  ? palette.textTertiary
                                  : palette.borderStrong,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _buildTutorialArrow(
            key: _tutorialNextKey,
            icon: LucideIcons.arrowRight,
            tooltip: _tutorialNextTooltip,
            onPressed: nextAction == null ? null : _goToNextTutorialPage,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialArrow({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final palette = context.omniPalette;
    final enabled = onPressed != null;
    return Material(
      color: enabled ? palette.surfacePrimary : palette.surfaceSecondary,
      shape: CircleBorder(side: BorderSide(color: palette.borderStrong)),
      child: IconButton(
        key: key,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: enabled ? palette.textPrimary : palette.textTertiary,
        disabledColor: palette.textTertiary,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildEnvironmentProgressNavigation({
    required bool success,
    required bool failed,
  }) {
    final canLeave = !_isEnvironmentBusy;
    final canContinue = canLeave && (success || failed);
    return SizedBox(
      key: const ValueKey('tutorial-environment-progress-navigation'),
      height: 58,
      child: Row(
        children: [
          _buildTutorialArrow(
            key: const ValueKey('tutorial-bottom-back'),
            icon: LucideIcons.arrowLeft,
            tooltip: _t('上一步', 'Previous'),
            onPressed: canLeave ? _handleBack : null,
          ),
          const Spacer(),
          _buildTutorialArrow(
            key: failed
                ? const ValueKey('tutorial-skip-environment-progress')
                : const ValueKey('tutorial-environment-continue'),
            icon: LucideIcons.arrowRight,
            tooltip: failed
                ? _t('暂不配置环境，先设置模型', 'Set up the environment later')
                : _t('继续配置模型', 'Continue to models'),
            onPressed: canContinue
                ? () => _goToPage(_TutorialPage.provider)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialPageHeading({
    required IconData icon,
    required String title,
  }) {
    final palette = context.omniPalette;
    return Row(
      key: const ValueKey('tutorial-page-heading'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          key: const ValueKey('tutorial-page-leading-icon'),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: palette.accentPrimary),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              key: const ValueKey('tutorial-page-title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortPage({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    final palette = context.omniPalette;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTutorialPageHeading(icon: icon, title: title),
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 22),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemPage() {
    final palette = context.omniPalette;
    return LayoutBuilder(
      key: const ValueKey('tutorial-system-page'),
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 700;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, compactHeight ? 14 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTutorialPageHeading(
                    icon: LucideIcons.box,
                    title: _t(
                      '选择本地 Linux 系统',
                      'Choose your local Linux system',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t(
                      '用于 Agent 执行命令和管理项目文件；系统与工作区只保留在本机。',
                      'Used for agent commands and project files. The system and workspace stay on-device.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: compactHeight ? 12 : 18),
                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final sideBySide = cardConstraints.maxWidth >= 560;
                      final width = sideBySide
                          ? (cardConstraints.maxWidth - 12) / 2
                          : cardConstraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: compactHeight ? 8 : 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _buildDistributionCard(
                              key: const ValueKey(
                                'tutorial-distribution-alpine',
                              ),
                              distribution: EmbeddedTerminalDistribution.alpine,
                              title: 'Alpine',
                              badge: _t('轻量推荐', 'Lightweight'),
                              description: _t(
                                '启动快、占用小，适合移动设备和大多数 Agent 工作。',
                                'Fast and compact for mobile devices and most agent tasks.',
                              ),
                              detail: _t(
                                'apk · 更省空间',
                                'apk · Smaller footprint',
                              ),
                              compact: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _buildDistributionCard(
                              key: const ValueKey(
                                'tutorial-distribution-ubuntu',
                              ),
                              distribution: EmbeddedTerminalDistribution.ubuntu,
                              title: 'Ubuntu',
                              badge: _t('熟悉生态', 'Familiar'),
                              description: _t(
                                '使用 apt，更接近常见服务器环境，软件生态更丰富。',
                                'Uses apt and closely matches common server environments.',
                              ),
                              detail: 'Ubuntu Base 24.04 · apt',
                              compact: true,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevelopmentPage() {
    return _buildShortPage(
      icon: LucideIcons.codeXml,
      title: _t('选择开发环境', 'Choose a development setup'),
      description: _t(
        '选择最接近你日常工作的初始工具组合，之后仍可单独增删。',
        'Pick the starter toolset closest to your work. Components can be changed later.',
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 2 : 1;
            final width = columns == 2
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _environmentPresets
                  .map(
                    (preset) => SizedBox(
                      width: width,
                      child: _buildEnvironmentPresetCard(preset),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolsPage() {
    return _buildShortPage(
      icon: LucideIcons.packagePlus,
      title: _t('添加需要的开发工具', 'Add the tools you need'),
      description: _t(
        '这些工具是可选项。编程 Agent 的账号登录可在安装完成后进行。',
        'These tools are optional. Sign in to coding agents after installation.',
      ),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _optionalTools
              .map((tool) => _buildOptionalToolChip(tool))
              .toList(growable: false),
        ),
        const SizedBox(height: 20),
        _buildEnvironmentSummary(),
      ],
    );
  }

  Widget _buildDistributionCard({
    required Key key,
    required EmbeddedTerminalDistribution distribution,
    required String title,
    required String badge,
    required String description,
    required String detail,
    bool compact = false,
  }) {
    final palette = context.omniPalette;
    final selected = _distribution == distribution;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: _isEnvironmentBusy
              ? null
              : () => _selectDistribution(distribution),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentPrimary.withValues(alpha: 0.09)
                  : palette.surfacePrimary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? palette.accentPrimary : palette.borderSubtle,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: context.isDarkTheme
                  ? const []
                  : [
                      BoxShadow(
                        color: palette.shadowColor,
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 36 : 40,
                      height: compact ? 36 : 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? palette.accentPrimary
                            : palette.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        distribution == EmbeddedTerminalDistribution.alpine
                            ? LucideIcons.mountain
                            : LucideIcons.circleDot,
                        size: compact ? 18 : 20,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    _buildBadge(badge, selected: selected),
                  ],
                ),
                SizedBox(height: compact ? 9 : 14),
                Text(
                  description,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    height: compact ? 1.4 : 1.55,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Row(
                  children: [
                    Icon(
                      selected
                          ? LucideIcons.circleCheck
                          : LucideIcons.hardDrive,
                      size: 15,
                      color: selected
                          ? palette.accentPrimary
                          : palette.textTertiary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        detail,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? palette.accentPrimary
                              : palette.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentPresetCard(_EnvironmentPreset preset) {
    final palette = context.omniPalette;
    final selected = preset.id == _environmentPresetId;
    final title = _t(preset.titleZh, preset.titleEn);
    final description = _t(preset.descriptionZh, preset.descriptionEn);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('tutorial-environment-${preset.id}'),
          onTap: _isEnvironmentBusy
              ? null
              : () => _selectEnvironmentPreset(preset.id),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentPrimary.withValues(alpha: 0.08)
                  : palette.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? palette.accentPrimary : palette.borderSubtle,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      preset.icon,
                      size: 20,
                      color: selected
                          ? palette.accentPrimary
                          : palette.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      selected ? LucideIcons.circleCheck : LucideIcons.circle,
                      size: 19,
                      color: selected
                          ? palette.accentPrimary
                          : palette.borderStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  preset.contents,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalToolChip(_OptionalTool tool) {
    final palette = context.omniPalette;
    final selected = _optionalToolIds.contains(tool.id);
    return Semantics(
      button: true,
      selected: selected,
      label: '${tool.label}, ${_t(tool.descriptionZh, tool.descriptionEn)}',
      child: FilterChip(
        key: ValueKey<String>('tutorial-tool-${tool.id}'),
        selected: selected,
        onSelected: _isEnvironmentBusy
            ? null
            : (_) => _toggleOptionalTool(tool.id),
        avatar: Icon(
          tool.icon,
          size: 16,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : palette.textSecondary,
        ),
        label: Text(tool.label),
        tooltip: _t(tool.descriptionZh, tool.descriptionEn),
        showCheckmark: false,
        selectedColor: palette.accentPrimary,
        backgroundColor: palette.surfacePrimary,
        side: BorderSide(
          color: selected ? palette.accentPrimary : palette.borderSubtle,
        ),
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _buildEnvironmentSummary() {
    final palette = context.omniPalette;
    final systemName = _distribution == EmbeddedTerminalDistribution.ubuntu
        ? 'Ubuntu'
        : 'Alpine';
    final extras = _optionalTools
        .where((tool) => _optionalToolIds.contains(tool.id))
        .map((tool) => tool.label)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.listChecks,
              size: 19,
              color: palette.accentPrimary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('将要配置', 'Setup summary'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$systemName · ${_t(_selectedEnvironmentPreset.titleZh, _selectedEnvironmentPreset.titleEn)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedEnvironmentPreset.contents,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${_t('附加', 'Extras')}: $extras',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentProgressPage() {
    final palette = context.omniPalette;
    final success = _environmentReady;
    final failed = _environmentFailed;
    final accent = failed
        ? Theme.of(context).colorScheme.error
        : success
        ? const Color(0xFF2F8F6B)
        : palette.accentPrimary;
    final progressLabel = '${(_environmentProgress * 100).round()}%';
    final systemName = _distribution == EmbeddedTerminalDistribution.ubuntu
        ? 'Ubuntu'
        : 'Alpine';
    return LayoutBuilder(
      key: const ValueKey('tutorial-environment-progress'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 60).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: _t('环境配置进度', 'Environment setup progress'),
                      value: progressLabel,
                      child: SizedBox(
                        width: 178,
                        height: 178,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                key: const ValueKey(
                                  'tutorial-environment-progress-ring',
                                ),
                                value: _environmentProgress.clamp(0, 1),
                                strokeWidth: 12,
                                backgroundColor: palette.borderSubtle,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                            Text(
                              progressLabel,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _environmentProgressTitle(
                        systemName: systemName,
                        failed: failed,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _environmentStage.isEmpty
                          ? _t('正在准备环境…', 'Preparing environment…')
                          : _localizedEnvironmentStage(_environmentStage),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildEnvironmentMilestones(),
                    const SizedBox(height: 16),
                    _buildEnvironmentSetupDetails(systemName),
                    const SizedBox(height: 14),
                    Text(
                      failed
                          ? _t(
                              '你的选择已经保留，可以检查网络后重试。',
                              'Your choices are preserved. Check your connection and try again.',
                            )
                          : success
                          ? _t(
                              '无需打开终端，Agent 会直接使用这套环境。',
                              'No terminal is needed. Agents will use this setup directly.',
                            )
                          : _t(
                              '安装时间取决于网络和所选工具，请保持应用在前台。',
                              'Setup time depends on your connection and selected tools. Keep the app open.',
                            ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    if (failed) ...[
                      const SizedBox(height: 28),
                      _buildPrimaryButton(
                        key: const ValueKey('tutorial-environment-retry'),
                        label: _t('重新配置', 'Try setup again'),
                        icon: LucideIcons.rotateCw,
                        onPressed: _startEnvironmentSetup,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildEnvironmentProgressNavigation(
                      success: success,
                      failed: failed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _environmentProgressTitle({
    required String systemName,
    required bool failed,
  }) {
    if (failed) {
      return _t('配置没有完成', 'Setup did not finish');
    }
    if (_environmentReady) {
      return _t('开发环境已准备完成', 'Your development setup is ready');
    }
    return switch (_environmentPhaseIndex(_environmentStage)) {
      0 => _t('正在保存配置', 'Saving your setup'),
      1 => _t('正在准备 $systemName 系统', 'Preparing the $systemName system'),
      2 => _t('正在安装开发工具', 'Installing development tools'),
      3 => _t('正在验证安装结果', 'Verifying the installation'),
      _ => _t('正在完成配置', 'Finishing setup'),
    };
  }

  Widget _buildEnvironmentMilestones() {
    final palette = context.omniPalette;
    final currentPhase = _environmentReady
        ? 4
        : _environmentPhaseIndex(_environmentStage);
    final labels = <String>[
      _t('保存选择', 'Save'),
      _t('准备系统', 'System'),
      _t('安装工具', 'Tools'),
      _t('验证', 'Verify'),
    ];
    return Row(
      children: List<Widget>.generate(labels.length, (index) {
        final completed = index < currentPhase || _environmentReady;
        final active = !_environmentReady && index == currentPhase;
        final failed = _environmentFailed && active;
        final color = failed
            ? Theme.of(context).colorScheme.error
            : completed || active
            ? palette.accentPrimary
            : palette.borderStrong;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: completed
                      ? color
                      : color.withValues(alpha: active ? 0.14 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                alignment: Alignment.center,
                child: active && !failed
                    ? SizedBox(
                        key: const ValueKey(
                          'tutorial-environment-active-milestone-spinner',
                        ),
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          value:
                              MediaQuery.maybeOf(context)?.disableAnimations ==
                                  true
                              ? 0.72
                              : null,
                          strokeWidth: 2.2,
                          color: color,
                        ),
                      )
                    : Icon(
                        failed
                            ? LucideIcons.x
                            : completed
                            ? LucideIcons.check
                            : LucideIcons.circle,
                        size: 15,
                        color: completed
                            ? Theme.of(context).colorScheme.onPrimary
                            : color,
                      ),
              ),
              const SizedBox(height: 7),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: completed || active
                      ? palette.textPrimary
                      : palette.textTertiary,
                  fontWeight: completed || active
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEnvironmentSetupDetails(String systemName) {
    final palette = context.omniPalette;
    final extras = _optionalTools
        .where((tool) => _optionalToolIds.contains(tool.id))
        .map((tool) => tool.label)
        .join(' · ');
    final tools = extras.isEmpty
        ? _selectedEnvironmentPreset.contents
        : '${_selectedEnvironmentPreset.contents} · $extras';

    Widget detailRow({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: palette.accentPrimary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        children: [
          detailRow(
            icon: LucideIcons.server,
            label: _t('系统', 'System'),
            value: systemName,
          ),
          const SizedBox(height: 11),
          detailRow(
            icon: LucideIcons.codeXml,
            label: _t('开发环境', 'Setup'),
            value: _t(
              _selectedEnvironmentPreset.titleZh,
              _selectedEnvironmentPreset.titleEn,
            ),
          ),
          const SizedBox(height: 11),
          detailRow(
            icon: LucideIcons.packageCheck,
            label: _t('安装组件', 'Packages'),
            value: tools,
          ),
        ],
      ),
    );
  }

  String _localizedEnvironmentStage(String value) {
    if (value.contains('基础 Agent CLI 包尚未完成预装')) {
      return _t(
        '终端系统已就绪，接下来配置所选开发工具',
        'The terminal system is ready; preparing your selected tools',
      );
    }
    if (!_isEnglish) return value;
    final stages = <String, String>{
      '开始准备内嵌终端环境': 'Starting the local terminal environment',
      '正在准备 workspace 和运行目录': 'Preparing the workspace and runtime directories',
      '正在初始化宿主终端运行时': 'Initializing the terminal runtime',
      '正在校验终端环境运行资源': 'Checking runtime resources',
      '正在安装终端环境运行资源': 'Installing runtime resources',
      '宿主终端环境校验完成': 'Runtime resources verified',
      '正在检查所选开发工具': 'Checking selected development tools',
      '正在安装所选开发工具': 'Installing selected development tools',
      '正在验证所选开发工具': 'Verifying selected development tools',
      '开发环境配置完成': 'Development environment ready',
      '所选开发工具已就绪': 'Selected development tools are ready',
    };
    for (final entry in stages.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return value;
  }

  Widget _buildProviderPage() {
    return _buildShortPage(
      icon: LucideIcons.brainCircuit,
      title: _t('选择模型提供商', 'Choose a model provider'),
      description: _t(
        '选择你已有账号或 API Key 的服务，下一页再填写连接信息。',
        'Choose a service for which you already have an account or API key. Connection details come next.',
      ),
      children: [
        if (_providerLoading)
          _buildLoadingCard(
            _t('正在读取已有模型配置…', 'Loading existing model settings…'),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620
                  ? 3
                  : constraints.maxWidth >= 420
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _providerOptions
                    .map(
                      (option) => SizedBox(
                        width: width,
                        child: _buildProviderOptionCard(option),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildProviderConnectionPage() {
    return _buildShortPage(
      icon: LucideIcons.plugZap,
      title: _t(
        '连接 ${_selectedProvider.label}',
        'Connect ${_selectedProvider.label}',
      ),
      description: _t(
        '连接成功后会读取可用模型。密钥仅保存在本机。',
        'Available models are loaded after connection. Your key stays on this device.',
      ),
      children: [
        _buildProviderForm(),
        if (_providerError != null) ...[
          const SizedBox(height: 12),
          _buildInlineError(_providerError!),
        ],
      ],
    );
  }

  Widget _buildModelInventoryPage() {
    return _buildShortPage(
      icon: LucideIcons.boxes,
      title: _t('确认可用模型', 'Review available models'),
      description: _t(
        '若服务没有返回模型列表，可以手动添加文档中的准确模型 ID。',
        'If the service does not return a model list, add an exact model ID from its documentation.',
      ),
      children: [
        _buildModelInventory(),
        if (_providerError != null) ...[
          const SizedBox(height: 12),
          _buildInlineError(_providerError!),
        ],
      ],
    );
  }

  Widget _buildPrimaryScenesPage() {
    return _buildShortPage(
      icon: LucideIcons.workflow,
      title: _t('配置对话与 Agent 模型', 'Configure chat and agent models'),
      description: _t(
        '先使用同一个通用模型也没有问题，之后可在“场景模型”设置中调整。',
        'Using one general model for now is fine. You can refine these roles later.',
      ),
      children: [..._sceneDefinitions.take(3).map(_buildSceneModelCard)],
    );
  }

  Widget _buildMemoryScenesPage() {
    return _buildShortPage(
      icon: LucideIcons.database,
      title: _t('配置记忆模型', 'Configure memory models'),
      description: _t(
        '嵌入模型负责检索，整理模型负责归纳长期记忆。',
        'The embedding model powers retrieval, while the rollup model consolidates long-term memory.',
      ),
      children: [
        ..._sceneDefinitions.skip(3).map(_buildSceneModelCard),
        if (_providerError != null) ...[
          const SizedBox(height: 4),
          _buildInlineError(_providerError!),
        ],
      ],
    );
  }

  Widget _buildCompletionPage() {
    final palette = context.omniPalette;
    return LayoutBuilder(
      key: const ValueKey('tutorial-completion-page'),
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final heroSize = compact ? 82.0 : 104.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: [
                  _buildTutorialPageHeading(
                    icon: LucideIcons.rocket,
                    title: _t('开始探索', 'Start exploring'),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: heroSize,
                              height: heroSize,
                              decoration: BoxDecoration(
                                color: palette.accentPrimary.withValues(
                                  alpha: 0.11,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.accentPrimary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: heroSize * 0.62,
                                height: heroSize * 0.62,
                                decoration: BoxDecoration(
                                  color: palette.accentPrimary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  LucideIcons.check,
                                  size: compact ? 30 : 38,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 16 : 22),
                            Text(
                              _t('一切准备就绪', 'Everything is ready'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _t(
                                '你已经完成首次使用教程。现在可以创建对话、调用 Agent，并在真实项目中开始工作。',
                                'You have completed the first-use guide. Start a conversation, use an agent, and work on a real project.',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.textSecondary,
                                    height: 1.6,
                                  ),
                            ),
                            SizedBox(height: compact ? 18 : 26),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompletionCapability(
                                    icon: LucideIcons.squareTerminal,
                                    label: _t('本地环境', 'Local setup'),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _buildCompletionCapability(
                                    icon: LucideIcons.brainCircuit,
                                    label: _t('模型服务', 'Models'),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _buildCompletionCapability(
                                    icon: LucideIcons.messageCircle,
                                    label: _t('聊天功能', 'Chat'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletionCapability({
    required IconData icon,
    required String label,
  }) {
    final palette = context.omniPalette;
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: palette.accentPrimary),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOptionCard(_ProviderOption option) {
    final palette = context.omniPalette;
    final selected = option.id == _selectedProviderId;
    final displayLabel = option.id == 'custom'
        ? _t('兼容 API', 'Compatible API')
        : option.label;
    final vendor = ModelVendorCatalog.byKey(option.vendorKey);
    final iconSurface = switch (option.vendorKey) {
      'moonshot' => const Color(0xFF111827),
      'deepseek' => const Color(0xFFEEF1FF),
      'xiaomi' => const Color(0xFFFFF1E8),
      _ => palette.surfaceSecondary,
    };
    final iconColor = switch (option.vendorKey) {
      'xiaomi' => const Color(0xFFFF6900),
      _ => palette.textPrimary,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: displayLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('tutorial-provider-${option.id}'),
          onTap: _providerBusy ? null : () => _applyProviderOption(option),
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentPrimary.withValues(alpha: 0.09)
                  : palette.surfacePrimary,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? palette.accentPrimary : palette.borderSubtle,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  key: ValueKey<String>('tutorial-provider-icon-${option.id}'),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconSurface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: palette.borderSubtle.withValues(alpha: 0.8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: vendor == null
                      ? Icon(
                          LucideIcons.plugZap,
                          size: 19,
                          color: palette.textSecondary,
                        )
                      : ProviderVendorIcon(
                          vendor: vendor,
                          size: 21,
                          monochromeColor: iconColor,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.chevronRight,
                  size: 17,
                  color: selected
                      ? palette.accentPrimary
                      : palette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderForm() {
    final palette = context.omniPalette;
    final isCustom = _selectedProviderId == 'custom';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.keyRound,
                size: 19,
                color: palette.accentPrimary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _t('连接信息', 'Connection details'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildBadge(_t('仅保存在本机', 'On-device only'), selected: false),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('tutorial-provider-name'),
            controller: _providerNameController,
            enabled: !_providerBusy,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: _t('提供商名称', 'Provider name'),
              hint: _t('例如：公司模型网关', 'Example: Company model gateway'),
              icon: LucideIcons.building2,
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            key: const ValueKey('tutorial-provider-base-url'),
            controller: _baseUrlController,
            enabled: !_providerBusy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: _inputDecoration(
              label: 'API Base URL',
              hint: 'https://api.example.com/v1',
              icon: LucideIcons.globe2,
              helper: isCustom
                  ? _t(
                      '填写兼容 OpenAI 或 Anthropic 协议的 HTTPS 地址。',
                      'Use an HTTPS endpoint compatible with OpenAI or Anthropic.',
                    )
                  : _t(
                      '已按所选提供商填写，只有使用代理网关时才需要修改。',
                      'Pre-filled for this provider. Change it only when using a gateway.',
                    ),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            key: const ValueKey('tutorial-provider-api-key'),
            controller: _apiKeyController,
            enabled: !_providerBusy,
            obscureText: _obscureApiKey,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => unawaited(_configureProvider()),
            decoration: _inputDecoration(
              label: 'API Key',
              hint: isCustom ? _t('无鉴权时可留空', 'Optional without auth') : 'sk-…',
              icon: LucideIcons.key,
              suffix: IconButton(
                onPressed: () {
                  setState(() => _obscureApiKey = !_obscureApiKey);
                },
                tooltip: _obscureApiKey
                    ? _t('显示密钥', 'Show key')
                    : _t('隐藏密钥', 'Hide key'),
                icon: Icon(
                  _obscureApiKey ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInventory() {
    final palette = context.omniPalette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_modelOptions.isEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.packageSearch,
                  size: 20,
                  color: palette.textTertiary,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _providerConnected
                        ? _t(
                            '还没有可用模型。输入提供商文档中的模型 ID，例如 gpt-4.1-mini。',
                            'No models are available yet. Enter an exact model ID from the provider docs, such as gpt-4.1-mini.',
                          )
                        : _t(
                            '连接提供商后，这里会显示可用于聊天和场景配置的模型。',
                            'Connect a provider to load models for chat and background roles.',
                          ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Icon(
                  LucideIcons.circleCheck,
                  size: 19,
                  color: const Color(0xFF2F8F6B),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _t(
                      '已准备 ${_modelOptions.length} 个模型',
                      '${_modelOptions.length} models ready',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._modelOptions
                    .take(10)
                    .map(
                      (model) => Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceSecondary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          model.displayName.trim().isEmpty
                              ? model.id
                              : model.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                if (_modelOptions.length > 10)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${_modelOptions.length - 10}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_providerConnected) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('tutorial-manual-model'),
                    controller: _manualModelController,
                    enabled: !_providerBusy && !_sceneModelsSaving,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_addManualModel()),
                    decoration: _inputDecoration(
                      label: _t('手动添加模型 ID', 'Add a model ID manually'),
                      hint: 'model-name',
                      icon: LucideIcons.plus,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    key: const ValueKey('tutorial-add-manual-model'),
                    onPressed: _providerBusy || _sceneModelsSaving
                        ? null
                        : _addManualModel,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_t('添加', 'Add')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSceneModelCard(_SceneDefinition scene) {
    final palette = context.omniPalette;
    final selectedModel = _sceneModelSelections[scene.id];
    final validValue =
        selectedModel != null &&
            _modelOptions.any((model) => model.id == selectedModel)
        ? selectedModel
        : null;
    final saving = _savingSceneIds.contains(scene.id);
    return Container(
      key: ValueKey<String>('tutorial-scene-${scene.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: saving ? palette.accentPrimary : palette.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.accentPrimary,
                        ),
                      )
                    : Icon(scene.icon, size: 19, color: palette.accentPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(scene.descriptionZh, scene.descriptionEn),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              '${scene.id}-${_activeProfile?.id ?? 'none'}-${_modelOptions.length}',
            ),
            initialValue: validValue,
            isExpanded: true,
            items: _modelOptions
                .map(
                  (model) => DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(
                      model.displayName.trim().isEmpty
                          ? model.id
                          : '${model.displayName}  ·  ${model.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _sceneModelsSaving || _modelOptions.isEmpty
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _sceneModelSelections = <String, String>{
                        ..._sceneModelSelections,
                        scene.id: value,
                      };
                    });
                  },
            decoration: _inputDecoration(
              label: _t('此场景使用', 'Model for this role'),
              hint: _modelOptions.isEmpty
                  ? _t('请先连接并添加模型', 'Connect and add a model first')
                  : _t('选择模型', 'Choose a model'),
              icon: LucideIcons.cpu,
            ),
            dropdownColor: palette.surfacePrimary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: errorColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, size: 18, color: errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.omniPalette.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String label) {
    final palette = context.omniPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.accentPrimary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {required bool selected}) {
    final palette = context.omniPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? palette.accentPrimary.withValues(alpha: 0.14)
            : palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected ? palette.accentPrimary : palette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
    Widget? suffix,
  }) {
    final palette = context.omniPalette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: palette.borderSubtle),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, size: 19),
      suffixIcon: suffix,
      filled: true,
      fillColor: palette.surfaceSecondary,
      labelStyle: TextStyle(color: palette.textSecondary),
      hintStyle: TextStyle(color: palette.textTertiary),
      helperStyle: TextStyle(color: palette.textTertiary, height: 1.4),
      prefixIconColor: palette.textSecondary,
      suffixIconColor: palette.textSecondary,
      enabledBorder: border,
      disabledBorder: border,
      border: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accentPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
    );
  }

  Widget _buildPrimaryButton({
    required Key key,
    required String label,
    required IconData icon,
    required FutureOr<void> Function()? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
