import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

Future<void> signInWithGoogle(BuildContext context) async {
  try {
    // 1. Inicializa o plugin de plataforma
    await GoogleSignInPlatform.instance.init(const InitParameters());

    // 2. Dispara o fluxo de login
    final AuthenticationResults result = await GoogleSignInPlatform.instance.authenticate(
      const AuthenticateParameters(),
    );

    final GoogleSignInUserData? user = result.user;
    if (user == null) return; // Usuário cancelou

    // 3. Pega os tokens e os dados de autenticação corretos da v7
    final ClientAuthorizationTokenData? tokens = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: const <String>['email', 'profile'],
              userId: user.id,
              email: user.email,
              promptIfUnauthorized: true,
            ),
          ),
        );

    // 4. Passa o idToken obtido no resultado da autenticação para o Firebase
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens?.accessToken,
      idToken: result.idToken, // <--- Aqui estava o detalhe que gerava a credencial inválida
    );

    // 5. Autentica no Firebase
    await FirebaseAuth.instance.signInWithCredential(credential);

  } catch (e) {
    print('Erro detalhado no login com o Google: $e');
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erro no Login'),
        content: Text('Detalhes: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

extension on AuthenticationResults {
  String? get idToken => null;
}