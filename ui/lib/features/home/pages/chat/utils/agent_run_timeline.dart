import 'package:ui/models/chat_message_model.dart';
import 'package:ui/services/agent_message_kinds.dart';

class AgentRunTimelineEntry {
  const AgentRunTimelineEntry.message(this.message) : group = null;

  const AgentRunTimelineEntry.group(this.group) : message = null;

  final ChatMessageModel? message;
  final AgentRunTimelineGroup? group;

  bool get isMessage => message != null;

  bool get isUserMessage => message?.user == 1;

  String get key => message?.id ?? 'agent-run-${group!.taskId}';
}

/// Whether an agent turn is still producing output.
///
/// This is derived at render time from the set of in-flight task ids, never
/// from a persisted flag. A turn that is not in that set has ended — whether it
/// ended cleanly, was cancelled, or died with the process. Gating the run
/// header on a persisted `isFinal` boolean instead used to mean that one lost
/// bit removed the agent avatar, the "processed" label, and the fold all at
/// once.
enum AgentRunStatus { running, finished }

class AgentRunTimelineGroup {
  const AgentRunTimelineGroup({
    required this.taskId,
    required this.status,
    required this.agentId,
    required this.startedAt,
    this.finishedAt,
    required this.visibleMessagesNewestFirst,
    required this.processMessagesNewestFirst,
  });

  final String taskId;
  final AgentRunStatus status;

  /// Resolved once, when the group is built, so the live and restored render
  /// paths cannot disagree about which agent produced the turn.
  final String agentId;

  /// Run boundaries, carried on the group so the header does not have to
  /// re-derive elapsed time by scanning message timestamps.
  final DateTime startedAt;
  final DateTime? finishedAt;

  final List<ChatMessageModel> visibleMessagesNewestFirst;
  final List<ChatMessageModel> processMessagesNewestFirst;

  bool get isRunning => status == AgentRunStatus.running;

  bool get isEmpty =>
      visibleMessagesNewestFirst.isEmpty && processMessagesNewestFirst.isEmpty;

  List<ChatMessageModel> get visibleMessagesOldestFirst =>
      visibleMessagesNewestFirst.reversed.toList(growable: false);

  List<ChatMessageModel> get processMessagesOldestFirst =>
      processMessagesNewestFirst.reversed.toList(growable: false);

  int get thinkingCount => processMessagesNewestFirst
      .where((message) => _cardType(message) == 'deep_thinking')
      .length;

  int get toolCount => processMessagesNewestFirst
      .where((message) => _cardType(message) == 'agent_tool_summary')
      .length;
}

List<AgentRunTimelineEntry> buildAgentRunTimelineEntries(
  List<ChatMessageModel> messages, {
  Set<String> activeTaskIds = const <String>{},
  String? conversationAgentId,
}) {
  if (messages.isEmpty) {
    return const <AgentRunTimelineEntry>[];
  }

  final normalizedActiveTaskIds = activeTaskIds
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
  final emittedTaskIds = <String>{};
  final entries = <AgentRunTimelineEntry>[];

  for (final message in messages) {
    final taskId = agentRunParentTaskId(message);
    if (taskId == null) {
      entries.add(AgentRunTimelineEntry.message(message));
      continue;
    }
    if (emittedTaskIds.contains(taskId)) {
      if (!_isAgentRunCandidateMessage(message)) {
        entries.add(AgentRunTimelineEntry.message(message));
      }
      continue;
    }

    final group = _buildTimelineGroup(
      messages,
      taskId: taskId,
      isActive: normalizedActiveTaskIds.contains(taskId),
      conversationAgentId: conversationAgentId,
    );
    if (group == null) {
      entries.add(AgentRunTimelineEntry.message(message));
      continue;
    }

    entries.add(AgentRunTimelineEntry.group(group));
    emittedTaskIds.add(taskId);
  }

  // A turn that has been dispatched but has not streamed anything yet owns no
  // messages, so the loop above never reaches it. Surface exactly ONE header
  // for that state — "an agent is working and has produced nothing" is a single
  // condition, not one per in-flight id. Emitting one per id is what used to
  // stack up a column of avatars and "processing" rows.
  final hasRunningGroup = entries.any(
    (entry) => entry.group?.isRunning ?? false,
  );
  if (!hasRunningGroup) {
    final pendingTaskId = normalizedActiveTaskIds
        .where((taskId) => !emittedTaskIds.contains(taskId))
        .lastOrNull;
    if (pendingTaskId != null) {
      entries.insert(
        0,
        AgentRunTimelineEntry.group(
          AgentRunTimelineGroup(
            taskId: pendingTaskId,
            status: AgentRunStatus.running,
            agentId: resolveAgentRunAgentId(
              turnMessages: const <ChatMessageModel>[],
              conversationAgentId: conversationAgentId,
            ),
            startedAt: _pendingRunStartedAt(messages, pendingTaskId),
            visibleMessagesNewestFirst: const <ChatMessageModel>[],
            processMessagesNewestFirst: const <ChatMessageModel>[],
          ),
        ),
      );
    }
  }

  return entries;
}

/// When a dispatched-but-silent turn started.
///
/// Prefers the user message minted alongside the dispatch id (`<x>-user` for a
/// `<x>-ai` task), then the newest user message, so the elapsed counter starts
/// from when the user actually sent the prompt.
DateTime _pendingRunStartedAt(List<ChatMessageModel> messages, String taskId) {
  if (taskId.endsWith('-ai')) {
    final expectedUserId = '${taskId.substring(0, taskId.length - 3)}-user';
    for (final message in messages) {
      if (message.id == expectedUserId) {
        return message.createAt;
      }
    }
  }
  for (final message in messages) {
    if (message.user == 1) {
      return message.createAt;
    }
  }
  return DateTime.now();
}

DateTime? _boundaryTimestamp(
  List<ChatMessageModel> messages, {
  required bool earliest,
}) {
  DateTime? boundary;
  for (final message in messages) {
    final createAt = message.createAt;
    if (createAt.millisecondsSinceEpoch <= 0) {
      continue;
    }
    if (boundary == null ||
        (earliest ? createAt.isBefore(boundary) : createAt.isAfter(boundary))) {
      boundary = createAt;
    }
  }
  return boundary;
}

String? agentRunParentTaskId(ChatMessageModel message) {
  final raw =
      message.streamMeta?['parentTaskId'] ??
      message.cardData?['taskID'] ??
      message.cardData?['taskId'];
  final normalized = raw?.toString().trim() ?? '';
  if (normalized.isNotEmpty) {
    return normalized;
  }
  if (message.user == 1) {
    return null;
  }
  return _agentTaskIdFromEntryId(message.id) ??
      _agentTaskIdFromEntryId(message.contentId);
}

String agentRunKind(ChatMessageModel message) {
  return (message.streamMeta?['kind'] ?? '').toString().trim().toLowerCase();
}

int agentRunSequence(ChatMessageModel message) {
  return _wholeIntFromDynamic(message.streamMeta?['entrySeq']) ??
      _wholeIntFromDynamic(message.streamMeta?['seq']) ??
      _entrySequenceFromAgentEntryId(message.id) ??
      _entrySequenceFromAgentEntryId(message.contentId) ??
      -1;
}

int? _wholeIntFromDynamic(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    final asDouble = value.toDouble();
    if (asDouble.isFinite && asDouble == asDouble.truncateToDouble()) {
      return value.toInt();
    }
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

AgentRunTimelineGroup? _buildTimelineGroup(
  List<ChatMessageModel> messages, {
  required String taskId,
  required bool isActive,
  String? conversationAgentId,
}) {
  final taskMessages = messages
      .where((message) => agentRunParentTaskId(message) == taskId)
      .where(_isAgentRunCandidateMessage)
      .toList(growable: false);
  if (taskMessages.isEmpty) {
    return null;
  }
  final requestMessages = taskMessages
      .where(isAgentRequestMessage)
      .toList(growable: false);

  // Every agent turn is a group, however small. The old "needs at least two
  // messages" and "needs process messages" gates meant a plain question and
  // answer never grouped, and therefore never showed an agent avatar once it
  // came back from the database.
  final primaryVisibleMessage = _resolvePrimaryVisibleMessage(
    taskMessages,
    requestMessages: requestMessages,
  );
  if (primaryVisibleMessage == null && !isActive) {
    return null;
  }

  final visibleMessages = primaryVisibleMessage == null
      ? const <ChatMessageModel>[]
      : _resolveVisibleMessages(
          taskMessages,
          primaryVisibleMessage: primaryVisibleMessage,
        );
  final visibleIds = visibleMessages.map((message) => message.id).toSet();
  final processMessages =
      taskMessages
          .where((message) => !visibleIds.contains(message.id))
          .toList(growable: false)
        ..sort((left, right) => _compareNewestFirst(left, right));

  return AgentRunTimelineGroup(
    taskId: taskId,
    status: isActive ? AgentRunStatus.running : AgentRunStatus.finished,
    agentId: resolveAgentRunAgentId(
      turnMessages: taskMessages,
      conversationAgentId: conversationAgentId,
    ),
    startedAt:
        _boundaryTimestamp(taskMessages, earliest: true) ?? DateTime.now(),
    finishedAt: isActive
        ? null
        : _boundaryTimestamp(taskMessages, earliest: false),
    visibleMessagesNewestFirst: visibleMessages,
    processMessagesNewestFirst: processMessages,
  );
}

/// The one rule for "which agent produced this turn".
///
/// Per-message identity first, then the conversation's bound agent, then a
/// neutral icon. The live and restored paths used to answer this differently —
/// the live header could fall back to page state while the restored header
/// could not — which is why a reloaded turn showed the built-in assistant
/// avatar instead of the agent's brand.
String resolveAgentRunAgentId({
  required Iterable<ChatMessageModel> turnMessages,
  String? conversationAgentId,
}) {
  for (final message in turnMessages) {
    final agentId = message.agentId?.trim() ?? '';
    if (agentId.isNotEmpty) {
      return agentId;
    }
  }
  final fallback = conversationAgentId?.trim() ?? '';
  return fallback.isNotEmpty ? fallback : kGenericAgentId;
}

const String kGenericAgentId = 'generic-agent';

bool _isAgentRunCandidateMessage(ChatMessageModel message) {
  if (message.user == 1) {
    return false;
  }
  if (message.type == 1) {
    return message.user == 2;
  }
  if (message.type != 2) {
    return false;
  }
  final type = _cardType(message);
  return type == 'deep_thinking' ||
      type == 'agent_tool_summary' ||
      type == 'permission_section' ||
      isAgentRequestCardType(type);
}

/// Picks the message shown outside the collapsible process section.
///
/// A pending request (approval / user input) always wins because it needs a
/// reply. Otherwise it is simply the newest assistant text: whether the turn
/// has finished is answered by the active-task set, not by inspecting the
/// message, so there is nothing left to classify here.
ChatMessageModel? _resolvePrimaryVisibleMessage(
  List<ChatMessageModel> taskMessages, {
  required List<ChatMessageModel> requestMessages,
}) {
  if (requestMessages.isNotEmpty) {
    return _newestBySequence(requestMessages);
  }
  final aiTextMessages = taskMessages
      .where((message) => message.type == 1 && message.user == 2)
      .toList(growable: false);
  return aiTextMessages.isEmpty ? null : _newestBySequence(aiTextMessages);
}

List<ChatMessageModel> _resolveVisibleMessages(
  List<ChatMessageModel> taskMessages, {
  required ChatMessageModel primaryVisibleMessage,
}) {
  final visibleMessages = <ChatMessageModel>[primaryVisibleMessage];
  final primaryKind = agentRunKind(primaryVisibleMessage);
  if (primaryKind == 'permission_required') {
    visibleMessages.addAll(
      taskMessages.where(
        (message) =>
            message.id != primaryVisibleMessage.id &&
            _cardType(message) == 'permission_section',
      ),
    );
  }
  if (primaryKind == 'clarify_required' ||
      primaryKind == 'permission_required' ||
      isAgentRequestMessage(primaryVisibleMessage)) {
    visibleMessages.addAll(
      taskMessages.where(
        (message) =>
            message.id != primaryVisibleMessage.id &&
            isAgentRequestMessage(message),
      ),
    );
  }
  final orderedByNewest = visibleMessages.toList(growable: false)
    ..sort((left, right) => _compareNewestFirst(left, right));
  return orderedByNewest;
}

ChatMessageModel _newestBySequence(List<ChatMessageModel> messages) {
  final sorted = messages.toList(growable: false)
    ..sort((left, right) => _compareNewestFirst(left, right));
  return sorted.first;
}

int _compareNewestFirst(ChatMessageModel left, ChatMessageModel right) {
  final seqCompare = agentRunSequence(right).compareTo(agentRunSequence(left));
  if (seqCompare != 0) {
    return seqCompare;
  }
  return right.createAt.compareTo(left.createAt);
}

String _cardType(ChatMessageModel message) {
  return (message.cardData?['type'] ?? '').toString().trim();
}

String? _agentTaskIdFromEntryId(String? raw) {
  final id = raw?.trim() ?? '';
  if (id.isEmpty) {
    return null;
  }
  const suffixes = <String>[
    '-assistant',
    '-clarify',
    '-permission',
    '-error',
    '-thinking',
    '-text',
  ];
  for (final suffix in suffixes) {
    if (id.endsWith(suffix)) {
      return id.substring(0, id.length - suffix.length);
    }
  }
  const markers = <String>['-thinking-', '-text-', '-tool-', '-permission-'];
  for (final marker in markers) {
    final index = id.indexOf(marker);
    if (index > 0) {
      return id.substring(0, index);
    }
  }
  return null;
}

int? _entrySequenceFromAgentEntryId(String? raw) {
  final id = raw?.trim() ?? '';
  if (id.isEmpty) {
    return null;
  }
  final thinkingRound = _positiveSuffixAfterMarker(id, '-thinking-');
  if (thinkingRound != null) {
    return _phaseSequence(thinkingRound, 1);
  }
  if (id.endsWith('-thinking')) {
    return 1;
  }
  final textRound = _positiveSuffixAfterMarker(id, '-text-');
  if (textRound != null) {
    return _phaseSequence(textRound, 2);
  }
  if (id.endsWith('-text') || id.endsWith('-assistant')) {
    return 2;
  }
  final toolIndex = _positiveSuffixAfterMarker(id, '-tool-');
  if (toolIndex != null) {
    return _phaseSequence(toolIndex, 3);
  }
  return null;
}

int? _positiveSuffixAfterMarker(String value, String marker) {
  final index = value.lastIndexOf(marker);
  if (index < 0) {
    return null;
  }
  final suffix = value.substring(index + marker.length).trim();
  final parsed = int.tryParse(suffix);
  if (parsed == null || parsed < 1) {
    return null;
  }
  return parsed;
}

int _phaseSequence(int roundIndex, int phaseOffset) {
  return ((roundIndex - 1) * 3) + phaseOffset;
}
