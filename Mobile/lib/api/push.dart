import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

/// Projeto do Firebase, passado no build (--dart-define). Sem ele o app funciona igual, só sem push.
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projeto = String.fromEnvironment('FIREBASE_PROJECT_ID');

/// Notificações push no Android (pedido mudou de status, suporte respondeu) com o app fechado.
/// Com o app aberto os avisos já chegam pelo tempo real; o push cobre o resto.
class Push {
  Push._();

  static final Push instance = Push._();

  static bool get configurado =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _apiKey != '' && _appId != '' && _projeto != '';

  bool _iniciado = false;
  String? _token;
  StreamSubscription<String>? _renovacao;

  /// Toque na notificação: o app abre e quem estiver ouvindo decide para onde ir (pedido, suporte).
  final toques = StreamController<Map<String, dynamic>>.broadcast();

  Future<bool> _iniciar() async {
    if (_iniciado) return true;
    if (!configurado) return false;
    await Firebase.initializeApp(
      options: const FirebaseOptions(apiKey: _apiKey, appId: _appId, messagingSenderId: _senderId, projectId: _projeto),
    );
    FirebaseMessaging.onMessageOpenedApp.listen((m) => toques.add(m.data));
    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) toques.add(inicial.data);
    return _iniciado = true;
  }

  /// Depois de entrar: pede permissão (Android 13+) e manda o token deste celular para a API.
  Future<void> registrar() async {
    try {
      if (!await _iniciar()) return;
      final permissao = await FirebaseMessaging.instance.requestPermission();
      if (permissao.authorizationStatus == AuthorizationStatus.denied) return;

      // O token chega (e é renovado) por onRegistered; register() dispara o primeiro.
      _renovacao ??= FirebaseMessaging.instance.onRegistered.listen((t) {
        _token = t;
        _enviar(t).catchError((_) {});
      });
      await FirebaseMessaging.instance.register();
      if (_token != null) await _enviar(_token!);
    } catch (e) {
      // Push é um extra: se o Firebase falhar, o app segue com os avisos em tempo real.
      debugPrint('Push indisponível: $e');
    }
  }

  Future<void> _enviar(String token) =>
      Api.instance.post<void>('/api/usuarios/me/dispositivos', {'token': token, 'plataforma': 'android'});

  /// Antes de sair da conta: este celular para de receber os avisos dela.
  Future<void> remover() async {
    final token = _token;
    if (token == null) return;
    try {
      await Api.instance.delete<void>('/api/usuarios/me/dispositivos/${Uri.encodeComponent(token)}');
    } catch (_) {
      // Offline: o token fica órfão e a API apaga quando o Firebase recusar.
    }
    _token = null;
  }
}
