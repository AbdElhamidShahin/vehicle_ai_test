import 'package:url_launcher/url_launcher.dart';

class MapService {
  Future<bool> open(String value) async {
    final u = Uri.tryParse(value);
    if (u == null || value.isEmpty) return false;
    try {
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
