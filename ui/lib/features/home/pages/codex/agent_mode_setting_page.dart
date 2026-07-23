import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/services/codex_app_server_service.dart';
import 'package:ui/services/model_provider_config_service.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_section_title.dart';

enum _AgentFilter { all, available, unavailable }

class AgentModeSettingPage extends StatefulWidget {
  const AgentModeSettingPage({super.key});

  @override
  State<AgentModeSettingPage> createState() => _AgentModeSettingPageState();
}

class _AgentModeSettingPageState extends State<AgentModeSettingPage> {
  AcpAgentCatalog? _catalog;
  List<ModelProviderProfileSummary> _providers = const [];
  Map<String, List<ProviderModelOption>> _modelsByProvider = const {};
  _AgentFilter _filter = _AgentFilter.all;
  String _query = '';
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _busyAgentId;

  bool get _english =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'en';

  String _text(String zh, String en) => _english ? en : zh;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    }
    try {
      final results = await Future.wait<dynamic>([
        refresh
            ? CodexAppServerService.refreshAgents()
            : CodexAppServerService.listAgents(),
        ModelProviderConfigService.listProfiles(),
      ]);
      final catalog = results[0] as AcpAgentCatalog;
      final providerPayload = results[1] as ModelProviderProfilesPayload;
      final modelEntries = await Future.wait(
        providerPayload.profiles.map((profile) async {
          final models =
              await ModelProviderConfigService.getStoredModelOptionsForProfile(
                profile.id,
                profile: profile,
              );
          return MapEntry(profile.id, models);
        }),
      );
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _providers = providerPayload.profiles;
        _modelsByProvider = Map.fromEntries(modelEntries);
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = error.toString();
      });
    }
  }

  List<AcpAgentProfile> get _visibleAgents {
    final normalizedQuery = _query.trim().toLowerCase();
    return (_catalog?.agents ?? const <AcpAgentProfile>[])
        .where((agent) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              [
                agent.name,
                agent.description,
                agent.command,
              ].join(' ').toLowerCase().contains(normalizedQuery);
          if (!matchesQuery) return false;
          return switch (_filter) {
            _AgentFilter.all => true,
            _AgentFilter.available => agent.status == 'online',
            _AgentFilter.unavailable => agent.status != 'online',
          };
        })
        .toList(growable: false);
  }

  int _countFor(_AgentFilter filter) {
    final agents = _catalog?.agents ?? const <AcpAgentProfile>[];
    return switch (filter) {
      _AgentFilter.all => agents.length,
      _AgentFilter.available =>
        agents.where((agent) => agent.status == 'online').length,
      _AgentFilter.unavailable =>
        agents.where((agent) => agent.status != 'online').length,
    };
  }

  ModelProviderProfileSummary? _providerFor(String id) {
    for (final provider in _providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  Future<void> _select(AcpAgentProfile agent) async {
    if (_busyAgentId != null || agent.id == _catalog?.selectedAgentId) return;
    if (!agent.enabled || agent.status != 'online') {
      showToast(
        _text(
          '请先通过“初始化检测”，确认该 Agent 可用。',
          'Run Initialize first and make sure this Agent is available.',
        ),
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _busyAgentId = agent.id);
    try {
      final catalog = await CodexAppServerService.selectAgent(agent.id);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _error = null;
      });
      showToast(
        _text('已切换到 ${agent.name}', 'Switched to ${agent.name}'),
        type: ToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showToast(error.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busyAgentId = null);
    }
  }

  Future<void> _test(AcpAgentProfile agent) async {
    if (_busyAgentId != null || !agent.enabled) return;
    if (agent.managedAdapter && agent.status == 'unchecked') {
      showToast(
        _text(
          '首次检测会自动准备 ACP 适配器，下载可能需要一些时间。',
          'The first check prepares the ACP adapter and may take a moment.',
        ),
      );
    }
    setState(() => _busyAgentId = agent.id);
    try {
      final result = await CodexAppServerService.testAgent(agent.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final ok = result['ok'] == true;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            ok
                ? _text('ACP 初始化成功', 'ACP initialized')
                : _text('ACP 初始化失败', 'ACP initialization failed'),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              ok
                  ? _formatCapabilities(result['capabilities'])
                  : (result['error']?.toString() ??
                        _text('未知错误', 'Unknown error')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text('完成', 'Done')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showToast(error.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busyAgentId = null);
    }
  }

  String _formatCapabilities(dynamic value, {String indent = ''}) {
    if (value is Map) {
      return value.entries
          .map((entry) {
            final nested = entry.value;
            if (nested is Map || nested is List) {
              return '$indent${entry.key}:\n'
                  '${_formatCapabilities(nested, indent: '$indent  ')}';
            }
            return '$indent${entry.key}: $nested';
          })
          .join('\n');
    }
    if (value is List) {
      return value
          .map(
            (item) =>
                '$indent- '
                '${_formatCapabilities(item, indent: '$indent  ').trim()}',
          )
          .join('\n');
    }
    return '$indent$value';
  }

  Future<void> _edit([AcpAgentProfile? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final commandController = TextEditingController(
      text: existing?.command ?? '',
    );
    final argumentsController = TextEditingController(
      text: existing?.arguments.join('\n') ?? '',
    );
    final environmentController = TextEditingController(
      text:
          existing?.environment.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('\n') ??
          '',
    );
    final modelController = TextEditingController(
      text: existing?.modelId ?? '',
    );
    var providerId = existing?.providerProfileId ?? '';
    var enabled = existing?.enabled ?? true;
    final result = await showDialog<AcpAgentProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final models = _modelsByProvider[providerId] ?? const [];
          return AlertDialog(
            title: Text(
              existing == null
                  ? _text('添加自定义 ACP Agent', 'Add custom ACP Agent')
                  : _text('配置 ${existing.name}', 'Configure ${existing.name}'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (existing?.builtIn != true)
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: _text('名称', 'Name'),
                          hintText: 'My ACP Agent',
                        ),
                      )
                    else
                      Text(
                        existing!.description,
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commandController,
                      decoration: InputDecoration(
                        labelText: _text('启动命令或路径', 'Command or path'),
                        hintText: '/usr/local/bin/agent',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: argumentsController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: _text(
                          '启动参数（每行一个）',
                          'Arguments (one per line)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _text('统一 API 与模型', 'Unified API and model'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _text(
                        '密钥只保存在“模型提供商”，不会复制进 Agent 配置。',
                        'Credentials stay in Model Providers and are never copied into the Agent profile.',
                      ),
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: providerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _text('模型提供商', 'Model provider'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            _text(
                              '使用 Agent 自身登录/配置',
                              'Use Agent authentication/config',
                            ),
                          ),
                        ),
                        for (final provider in _providers)
                          DropdownMenuItem(
                            value: provider.id,
                            child: Text(provider.name),
                          ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          providerId = value ?? '';
                          final available =
                              _modelsByProvider[providerId] ?? const [];
                          if (available.isNotEmpty &&
                              !available.any(
                                (model) => model.id == modelController.text,
                              )) {
                            modelController.text = available.first.id;
                          }
                        });
                      },
                    ),
                    if (providerId.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: modelController,
                        decoration: InputDecoration(
                          labelText: _text('模型 ID', 'Model ID'),
                          hintText: _text(
                            '从下方选择或手动输入',
                            'Choose below or enter manually',
                          ),
                        ),
                      ),
                      if (models.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final model in models.take(12))
                              ActionChip(
                                label: Text(
                                  model.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () => setDialogState(
                                  () => modelController.text = model.id,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        _text('高级启动环境', 'Advanced launch environment'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        _text(
                          'API Key/Base URL 变量会被忽略，请在模型提供商中配置。',
                          'API credential variables are ignored; configure them in Model Providers.',
                        ),
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      children: [
                        TextField(
                          controller: environmentController,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'KEY=VALUE',
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_text('启用 Agent', 'Enable Agent')),
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_text('取消', 'Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final command = commandController.text.trim();
                  final model = modelController.text.trim();
                  if (name.isEmpty || command.isEmpty) return;
                  if (providerId.isNotEmpty && model.isEmpty) {
                    showToast(
                      _text(
                        '绑定模型提供商后必须选择模型。',
                        'Select a model when a provider is bound.',
                      ),
                      type: ToastType.warning,
                    );
                    return;
                  }
                  final environment = <String, String>{};
                  for (final line in environmentController.text.split('\n')) {
                    final separator = line.indexOf('=');
                    if (separator <= 0) continue;
                    final key = line.substring(0, separator).trim();
                    if (key.isEmpty) continue;
                    environment[key] = line.substring(separator + 1);
                  }
                  Navigator.of(dialogContext).pop(
                    AcpAgentProfile(
                      id: existing?.id ?? '',
                      name: existing?.builtIn == true ? existing!.name : name,
                      description: existing?.description ?? '',
                      command: command,
                      arguments: argumentsController.text
                          .split('\n')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList(growable: false),
                      environment: environment,
                      providerProfileId: providerId,
                      modelId: providerId.isEmpty ? '' : model,
                      enabled: enabled,
                      builtIn: existing?.builtIn ?? false,
                      source: existing?.source ?? 'custom',
                    ),
                  );
                },
                child: Text(_text('保存', 'Save')),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    commandController.dispose();
    argumentsController.dispose();
    environmentController.dispose();
    modelController.dispose();
    if (result == null) return;
    try {
      final catalog = await CodexAppServerService.saveAgent(result);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      showToast(error.toString(), type: ToastType.error);
    }
  }

  Future<void> _delete(AcpAgentProfile agent) async {
    if (agent.builtIn || _busyAgentId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('删除 Agent？', 'Delete Agent?')),
        content: Text(
          _text(
            '将删除“${agent.name}”的配置，不会卸载对应命令。',
            'This removes “${agent.name}” from the catalog without uninstalling its command.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_text('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyAgentId = agent.id);
    try {
      final catalog = await CodexAppServerService.deleteAgent(agent.id);
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (error) {
      if (!mounted) return;
      showToast(error.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busyAgentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final dark = context.isDarkTheme;
    final background = dark ? palette.pageBackground : AppColors.background;
    final card = dark ? palette.surfacePrimary : Colors.white;
    final agents = _visibleAgents;
    final managed = agents.where((agent) => agent.builtIn).toList();
    final custom = agents.where((agent) => !agent.builtIn).toList();
    return Scaffold(
      backgroundColor: background,
      appBar: CommonAppBar(
        title: _text('Agent 模式', 'Agent mode'),
        primary: true,
        actions: [
          IconButton(
            tooltip: _text('刷新检测', 'Refresh detection'),
            onPressed: _refreshing ? null : () => _load(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: _text('添加自定义 ACP Agent', 'Add custom ACP Agent'),
            onPressed: _busyAgentId == null ? _edit : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && (_catalog?.agents.isEmpty ?? true)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: Text(_text('重试', 'Retry')),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  SettingsSectionTitle(
                    label: _text('托管 Agent', 'Managed Agents'),
                    subtitle: _text(
                      '预置 Agent 始终显示；状态由命令检测和 ACP initialize 握手产生。API Key、Base URL 与模型统一来自“模型提供商”。',
                      'Built-in Agents always remain visible. Status comes from command detection and the ACP initialize handshake. API keys, endpoints, and models come from Model Providers.',
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: _text('搜索 Agent', 'Search Agents'),
                      filled: true,
                      fillColor: card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_AgentFilter>(
                    segments: [
                      ButtonSegment(
                        value: _AgentFilter.all,
                        label: Text(
                          '${_text('全部', 'All')} ${_countFor(_AgentFilter.all)}',
                        ),
                      ),
                      ButtonSegment(
                        value: _AgentFilter.available,
                        label: Text(
                          '${_text('可用', 'Available')} '
                          '${_countFor(_AgentFilter.available)}',
                        ),
                      ),
                      ButtonSegment(
                        value: _AgentFilter.unavailable,
                        label: Text(
                          '${_text('不可用', 'Unavailable')} '
                          '${_countFor(_AgentFilter.unavailable)}',
                        ),
                      ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) =>
                        setState(() => _filter = values.first),
                  ),
                  if (_providers.isEmpty) ...[
                    const SizedBox(height: 12),
                    _ProviderNotice(
                      text: _text(
                        '尚无可用模型提供商。请先配置统一 API 与模型。',
                        'No model provider is ready. Configure unified API and models first.',
                      ),
                      action: _text('打开模型提供商', 'Open Model Providers'),
                      onTap: () =>
                          GoRouterManager.push('/home/model_provider_setting'),
                    ),
                  ],
                  if (managed.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel(_text('预置 Agent', 'Built-in Agents')),
                    const SizedBox(height: 8),
                    for (final agent in managed) ...[
                      _AgentCard(
                        agent: agent,
                        providerName: _providerFor(
                          agent.providerProfileId,
                        )?.name,
                        selected: agent.id == _catalog?.selectedAgentId,
                        busy: agent.id == _busyAgentId,
                        onSelect: () => _select(agent),
                        onTest: () => _test(agent),
                        onConfigure: () => _edit(agent),
                        cardColor: card,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (custom.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionLabel(_text('自定义 Agent', 'Custom Agents')),
                    const SizedBox(height: 8),
                    for (final agent in custom) ...[
                      _AgentCard(
                        agent: agent,
                        providerName: _providerFor(
                          agent.providerProfileId,
                        )?.name,
                        selected: agent.id == _catalog?.selectedAgentId,
                        busy: agent.id == _busyAgentId,
                        onSelect: () => _select(agent),
                        onTest: () => _test(agent),
                        onConfigure: () => _edit(agent),
                        onDelete: () => _delete(agent),
                        cardColor: card,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (agents.isEmpty) ...[
                    const SizedBox(height: 42),
                    Center(
                      child: Text(
                        _text('没有匹配的 Agent', 'No matching Agents'),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionLabel(String value) {
    return Text(
      value,
      style: TextStyle(
        color: context.omniPalette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ProviderNotice extends StatelessWidget {
  const _ProviderNotice({
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.omniPalette.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.omniPalette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.providerName,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onTest,
    required this.onConfigure,
    this.onDelete,
    required this.cardColor,
  });

  final AcpAgentProfile agent;
  final String? providerName;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onTest;
  final VoidCallback onConfigure;
  final VoidCallback? onDelete;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final english =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'en';
    final status = _statusPresentation(agent.status, english);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? palette.accentPrimary : palette.borderSubtle,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 20,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          !agent.enabled
                              ? (english ? 'Disabled' : '已停用')
                              : status.label,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'configure') onConfigure();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'configure',
                      child: Text(english ? 'Configure' : '配置'),
                    ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(english ? 'Delete' : '删除'),
                      ),
                  ],
                ),
            ],
          ),
          if (agent.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              agent.description,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          SelectableText(
            ([agent.command, ...agent.arguments]).join(' '),
            style: TextStyle(
              color: palette.textTertiary,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            providerName == null
                ? (english
                      ? 'API: Agent authentication/config'
                      : 'API：使用 Agent 自身登录/配置')
                : 'API: $providerName'
                      '${agent.modelId.isEmpty ? '' : ' · ${agent.modelId}'}',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          if ((agent.lastCheckError ?? '').isNotEmpty &&
              agent.status != 'online') ...[
            const SizedBox(height: 6),
            Text(
              agent.lastCheckError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy || !agent.enabled || agent.status == 'missing'
                    ? null
                    : onTest,
                child: Text(
                  agent.managedAdapter &&
                          agent.status == 'unchecked' &&
                          agent.lastCheckError?.contains('will be prepared') ==
                              true
                      ? (english ? 'Prepare & initialize' : '准备并初始化')
                      : (english ? 'Initialize' : '初始化检测'),
                ),
              ),
              FilledButton.tonal(
                onPressed:
                    busy ||
                        !agent.enabled ||
                        agent.status != 'online' ||
                        selected
                    ? null
                    : onSelect,
                child: Text(
                  selected
                      ? (english ? 'Selected' : '当前使用')
                      : (english ? 'Use Agent' : '使用'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

({String label, Color color}) _statusPresentation(String status, bool english) {
  return switch (status) {
    'online' => (
      label: english ? 'Available' : '可用',
      color: const Color(0xFF2EAF67),
    ),
    'missing' => (
      label: english ? 'Not installed' : '未安装',
      color: const Color(0xFF98A2B3),
    ),
    'offline' => (
      label: english ? 'Initialization failed' : '初始化失败',
      color: const Color(0xFFE05252),
    ),
    _ => (label: english ? 'Unchecked' : '未检测', color: const Color(0xFFE3A52B)),
  };
}
