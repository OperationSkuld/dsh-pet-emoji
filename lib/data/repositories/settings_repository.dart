import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_links.dart';
import '../models/app_settings.dart';

/// 设置持久化。API Key 明文存于 SharedPreferences——
/// 见 docs/ARCHITECTURE.md「安全边界」，本项目不引入原生安全存储以保持零额外原生依赖。
class SettingsRepository {
  SettingsRepository._(this._prefs, this._settings);

  final SharedPreferences _prefs;
  AppSettings _settings;

  static const _kApiKey = 'dsh.apiKey';
  static const _kBaseUrl = 'dsh.baseUrl';
  static const _kModel = 'dsh.model';
  static const _kAmbient = 'dsh.ambient';
  static const _kLlmTagging = 'dsh.llmTagging';
  static const _kSemanticPanel = 'dsh.semanticPanel';
  static const _kPetScale = 'dsh.petScale';
  static const _kAlwaysOnTop = 'dsh.alwaysOnTop';
  static const _kPetBackground = 'dsh.petBackground';
  static const _kSpeech = 'dsh.speech';

  AppSettings get value => _settings;

  static Future<SettingsRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(
      apiKey: prefs.getString(_kApiKey) ?? '',
      baseUrl: prefs.getString(_kBaseUrl) ?? kDefaultBaseUrl,
      model: prefs.getString(_kModel) ?? kDefaultModel,
      ambientAnimations: prefs.getBool(_kAmbient) ?? true,
      llmSemanticTagging: prefs.getBool(_kLlmTagging) ?? false,
      showSemanticPanel: prefs.getBool(_kSemanticPanel) ?? false,
      petScale: prefs.getDouble(_kPetScale) ?? 1.0,
      petWindowAlwaysOnTop: prefs.getBool(_kAlwaysOnTop) ?? true,
      petWindowBackground: PetWindowBackground.parse(prefs.getString(_kPetBackground)),
      speechBubble: prefs.getBool(_kSpeech) ?? true,
    );
    return SettingsRepository._(prefs, settings);
  }

  Future<void> save(AppSettings settings) async {
    _settings = settings;
    await Future.wait([
      _prefs.setString(_kApiKey, settings.apiKey),
      _prefs.setString(_kBaseUrl, settings.baseUrl),
      _prefs.setString(_kModel, settings.model),
      _prefs.setBool(_kAmbient, settings.ambientAnimations),
      _prefs.setBool(_kLlmTagging, settings.llmSemanticTagging),
      _prefs.setBool(_kSemanticPanel, settings.showSemanticPanel),
      _prefs.setDouble(_kPetScale, settings.petScale),
      _prefs.setBool(_kAlwaysOnTop, settings.petWindowAlwaysOnTop),
      _prefs.setString(_kPetBackground, settings.petWindowBackground.name),
      _prefs.setBool(_kSpeech, settings.speechBubble),
    ]);
  }
}
