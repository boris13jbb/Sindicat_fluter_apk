import 'package:flutter/material.dart';

import '../../services/secure_attendance_qr_service.dart';

Future<void> showScannerApprovalDialog(
  BuildContext context, {
  SecureAttendanceQrService? service,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ScannerApprovalDialog(service: service),
  );
}

class ScannerApprovalDialog extends StatefulWidget {
  const ScannerApprovalDialog({super.key, this.service});

  final SecureAttendanceQrService? service;

  @override
  State<ScannerApprovalDialog> createState() => _ScannerApprovalDialogState();
}

class _ScannerApprovalDialogState extends State<ScannerApprovalDialog> {
  late final SecureAttendanceQrService _service;
  final _scannerIdController = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecureAttendanceQrService();
  }

  @override
  void dispose() {
    _scannerIdController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final scannerId = _scannerIdController.text.trim();
    if (scannerId.isEmpty) {
      setState(() {
        _success = false;
        _message = 'Introduce el Scanner ID.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _success = false;
      _message = null;
    });
    try {
      await _service.approveScannerDevice(scannerId: scannerId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = true;
        _message = 'Escáner aprobado correctamente.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = false;
        _message = SecureAttendanceQrService.userFacingActivationError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aprobar escáner'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Introduce el identificador mostrado en el dispositivo del '
              'operador.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scanner_approval_id_input'),
              controller: _scannerIdController,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Scanner ID',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!_busy) _approve();
              },
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                key: const Key('scanner_approval_message'),
                style: TextStyle(
                  color: _success
                      ? Colors.green.shade800
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          key: const Key('approve_scanner_button'),
          onPressed: _busy ? null : _approve,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text('Aprobar'),
        ),
      ],
    );
  }
}
