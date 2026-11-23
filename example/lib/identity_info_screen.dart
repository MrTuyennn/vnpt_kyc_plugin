import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:flutter/material.dart';
import 'api_result_screen.dart';

class IdentityInfoScreen extends StatefulWidget {
  const IdentityInfoScreen({super.key, required this.result, this.artifactDir});
  final PipelineResult result;
  final String? artifactDir;
  @override
  State<IdentityInfoScreen> createState() => _IdentityInfoScreenState();
}

class _IdentityInfoScreenState extends State<IdentityInfoScreen> {
  late final Map<String, TextEditingController> fields;
  @override
  void initState() {
    super.initState();
    final card = vnptResponseObject(widget.result.ocrJson) ?? {};
    fields = {
      'Họ và tên': TextEditingController(text: '${card['name'] ?? ''}'),
      'Ngày sinh': TextEditingController(text: '${card['birth_day'] ?? ''}'),
      'Giới tính': TextEditingController(text: '${card['gender'] ?? ''}'),
      'Số Căn Cước': TextEditingController(text: '${card['id'] ?? ''}'),
      'Nơi cấp': TextEditingController(text: '${card['issue_place'] ?? ''}'),
      'Ngày cấp': TextEditingController(text: '${card['issue_date'] ?? ''}'),
      'Ngày hết hạn': TextEditingController(
        text: '${card['valid_date'] ?? ''}',
      ),
      'Địa chỉ thường trú': TextEditingController(
        text: '${card['recent_location'] ?? ''}',
      ),
      'Số điện thoại': TextEditingController(),
      'Email': TextEditingController(),
      'Tỉnh / Thành phố': TextEditingController(),
      'Phường / Xã': TextEditingController(),
      'Địa chỉ cụ thể': TextEditingController(),
      'Ngân hàng': TextEditingController(),
      'Số tài khoản': TextEditingController(),
      'Chủ tài khoản': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: fields[name],
          decoration: InputDecoration(
            hintText: 'Nhập $name',
            filled: true,
            fillColor: const Color(0xff383a3d),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );
  Widget pair(String a, String b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: field(a)),
      const SizedBox(width: 12),
      Expanded(child: field(b)),
    ],
  );
  Widget heading(String title, String caption) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          caption,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xff1c1e20),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xffffbb32),
        surface: Color(0xff1c1e20),
      ),
    ),
    child: Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Xác minh danh tính'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('✓  Loại tài khoản'),
                  Text('✓  Danh tính'),
                  Text(
                    '③  Thông tin',
                    style: TextStyle(color: Color(0xffffbb32)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  heading(
                    'Thông tin cá nhân',
                    'Vui lòng kiểm tra thông tin được trích xuất từ Căn Cước',
                  ),
                  field('Họ và tên'),
                  pair('Ngày sinh', 'Giới tính'),
                  pair('Số Căn Cước', 'Nơi cấp'),
                  pair('Ngày cấp', 'Ngày hết hạn'),
                  field('Địa chỉ thường trú'),
                  heading(
                    'Thông tin liên hệ',
                    'Thông tin dùng để liên hệ khi cần',
                  ),
                  field('Số điện thoại'),
                  field('Email'),
                  field('Tỉnh / Thành phố'),
                  field('Phường / Xã'),
                  field('Địa chỉ cụ thể'),
                  heading(
                    'Tài khoản ngân hàng thụ hưởng',
                    'Thông tin nhập tại đây chỉ dùng để kiểm thử giao diện',
                  ),
                  field('Ngân hàng'),
                  field('Số tài khoản'),
                  field('Chủ tài khoản'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApiResultScreen(
                            result: widget.result,
                            artifactDir: widget.artifactDir,
                          ),
                        ),
                      ),
                      child: const Text('Tiếp tục'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
