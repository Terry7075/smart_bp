import 'package:url_launcher/url_launcher.dart';

class DriverActionService {
  Future<void> callPhone(String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitized.isEmpty) {
      throw StateError('Phone number is empty.');
    }

    final uri = Uri(scheme: 'tel', path: sanitized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open phone dialer.');
    }
  }

  Future<void> openNavigation(String destination) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) {
      throw StateError('Destination is empty.');
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': trimmed,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open navigation.');
    }
  }
}
