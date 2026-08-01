import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 模型能力标签组件
class ModelCapabilityTag extends StatelessWidget {
  const ModelCapabilityTag({
    super.key,
    this.attachment = false,
    this.reasoning = false,
    this.toolCall = false,
    this.structuredOutput = false,
    this.temperature = false,
    this.inputModalities = const [],
    this.outputModalities = const [],
    this.size = 12,
  });

  final bool attachment;
  final bool reasoning;
  final bool toolCall;
  final bool structuredOutput;
  final bool temperature;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final tags = <Widget>[];

    // 附件能力标签
    if (attachment) {
      tags.add(_buildTag(
        icon: LucideIcons.paperclip,
        label: '附件',
        color: palette.primary,
        size: size,
      ));
    }

    // 推理能力标签
    if (reasoning) {
      tags.add(_buildTag(
        icon: LucideIcons.brainCircuit,
        label: '推理',
        color: palette.tertiary,
        size: size,
      ));
    }

    // 工具调用能力标签
    if (toolCall) {
      tags.add(_buildTag(
        icon: LucideIcons.wrench,
        label: '工具',
        color: palette.secondary,
        size: size,
      ));
    }

    // 结构化输出标签
    if (structuredOutput) {
      tags.add(_buildTag(
        icon: LucideIcons.codeBlock,
        label: '结构化',
        color: palette.primaryContainer,
        size: size,
      ));
    }

    // 温度参数标签
    if (temperature) {
      tags.add(_buildTag(
        icon: LucideIcons.zap,
        label: '温度',
        color: palette.error,
        size: size,
      ));
    }

    // 输入模态标签（如文本、图像等）
    for (final modality in inputModalities) {
      tags.add(_buildTag(
        icon: _getModalityIcon(modality),
        label: _getModalityLabel(modality),
        color: palette.tertiaryContainer,
        size: size,
      ));
    }

    // 输出模态标签
    for (final modality in outputModalities) {
      tags.add(_buildTag(
        icon: _getModalityIcon(modality),
        label: _getModalityLabel(modality),
        color: palette.tertiaryContainer,
        size: size,
      ));
    }

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags,
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
    required double size,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 1.5, vertical: size * 0.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 1.5),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: size * 0.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: color),
          SizedBox(width: size * 0.5),
          Text(
            label,
            style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModalityIcon(String modality) {
    switch (modality.toLowerCase()) {
      case 'text':
      case 'textual':
        return LucideIcons.type;
      case 'image':
      case 'vision':
      case 'image_url':
        return LucideIcons.image;
      case 'audio':
      case 'speech':
        return LucideIcons.mic;
      case 'video':
        return LucideIcons.video;
      case 'file':
        return LucideIcons.fileText;
      default:
        return LucideIcons.circle;
    }
  }

  String _getModalityLabel(String modality) {
    switch (modality.toLowerCase()) {
      case 'text':
      case 'textual':
        return '文本';
      case 'image':
      case 'vision':
      case 'image_url':
        return '图像';
      case 'audio':
      case 'speech':
        return '音频';
      case 'video':
        return '视频';
      case 'file':
        return '文件';
      default:
        return modality;
    }
  }
}
