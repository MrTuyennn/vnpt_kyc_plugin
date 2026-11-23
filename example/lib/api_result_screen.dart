import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApiResultScreen extends StatelessWidget {
  const ApiResultScreen({
    super.key,
    required this.result,
    this.artifactDir,
    this.canRetry = false,
  });

  final PipelineResult result;
  final String? artifactDir;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final card = vnptResponseObject(result.ocrJson);
    final ocrOk = vnptOcrAccepted(result.ocrJson);
    final livenessOk = vnptLivenessAccepted(result.liveness3dJson);
    final success = result.success && ocrOk && livenessOk;
    final statusColor = success ? colors.primary : colors.error;
    final values = [
      ('Họ và tên', card?['name']),
      ('Số CCCD', card?['id']),
      ('Ngày sinh', card?['birth_day']),
      ('Giới tính', card?['gender']),
      ('Quốc tịch', card?['nationality']),
      ('Quê quán', card?['origin_location']),
      ('Nơi thường trú', card?['recent_location']),
      ('Ngày cấp', card?['issue_date']),
      ('Có giá trị đến', card?['valid_date']),
      ('Nơi cấp', card?['issue_place']),
    ];
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả xác thực')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                children: [
                  Icon(
                    success ? Icons.verified_outlined : Icons.info_outline,
                    color: statusColor,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    success ? 'Xác thực thành công' : 'Chưa hoàn tất xác thực',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!success && result.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(result.errorMessage, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  _StatusRow(
                    'CCCD',
                    ocrOk ? 'Đã đọc thông tin' : 'Chưa xác nhận',
                    ocrOk,
                  ),
                  _StatusRow(
                    'Khuôn mặt',
                    livenessOk ? 'Liveness đạt' : 'Chưa xác nhận',
                    livenessOk,
                  ),
                  if (ocrOk) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Thông tin trên CCCD',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final (label, value) in values)
                      if (value != null && value.toString().trim().isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(label, style: theme.textTheme.bodySmall),
                          subtitle: SelectableText(
                            value.toString(),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                  ],
                  if (result.errorCode.isNotEmpty ||
                      result.ocrJson.isNotEmpty ||
                      result.liveness3dJson.isNotEmpty ||
                      artifactDir != null) ...[
                    const SizedBox(height: 16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      initiallyExpanded: !success,
                      title: const Text('Chi tiết kiểm tra và lỗi'),
                      children: [
                        if (result.errorCode.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Mã: ${result.errorCode}'),
                          ),
                        if (result.errorMessage.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Chi tiết lỗi'),
                            subtitle: SelectableText(result.errorMessage),
                          ),
                        if (result.ocrJson.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('OCR'),
                            subtitle: SelectableText(result.ocrJson),
                          ),
                        if (result.liveness3dJson.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Liveness'),
                            subtitle: SelectableText(result.liveness3dJson),
                          ),
                        if (artifactDir case final dir?)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Sao chép đường dẫn ảnh và dữ liệu',
                            ),
                            trailing: const Icon(Icons.copy_outlined),
                            onTap: () =>
                                Clipboard.setData(ClipboardData(text: dir)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => navigator.pop(canRetry),
                child: Text(canRetry ? 'Quay lại để thử lại' : 'Hoàn tất'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.status, this.ok);
  final String label;
  final String status;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle_outline : Icons.info_outline,
        color: ok ? colors.primary : colors.error,
      ),
      title: Text(label),
      trailing: Text(
        status,
        style: TextStyle(color: ok ? colors.primary : colors.error),
      ),
    );
  }
}
