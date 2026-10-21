import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_version.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../application/operations_controller.dart';
import '../domain/app_operations.dart';

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support =
        ref.watch(operationsProvider).data.support ?? AppSupport.defaults;
    return Scaffold(
      appBar: const AppPageBar(title: Text('反馈与帮助')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    Text('反馈问题', style: Theme.of(context).textTheme.titleLarge),
                    AppButton.withIcon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                'App：Asasfans Next $appVersion\n系统：${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n\n问题描述：\n\n操作步骤：\n\n预期结果：\n',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制反馈模板')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('复制反馈模板'),
                      tonal: true,
                    ),
                    AppButton.withIcon(
                      onPressed: () => _open(context, ref, support.feedback),
                      icon: const Icon(Icons.feedback_outlined),
                      label: const Text('提交反馈'),
                      selected: true,
                    ),
                    if (support.contact != null)
                      AppButton.withIcon(
                        onPressed: () => _open(context, ref, support.contact!),
                        icon: const Icon(Icons.alternate_email),
                        label: const Text('联系开发者'),
                        tonal: true,
                      ),
                    if (support.help != null)
                      AppButton.withIcon(
                        onPressed: () => _open(context, ref, support.help!),
                        icon: const Icon(Icons.help_outline),
                        label: const Text('帮助与下载'),
                        tonal: true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final opened = await ref.read(externalLinkServiceProvider).open(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }
}
