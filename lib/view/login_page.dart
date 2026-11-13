import 'package:apk_auth/services/google_login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';
import '../components/social_button.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> forgotPassword() async {
    if (emailController.text.trim().isEmpty) {
      showAlert('Digite seu email primeiro.');
      return;
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: emailController.text.trim(),
    );
    if (!mounted) return;
    showAlert('Enviamos um link para seu email!');
  }

  Future<void> signIn() async {
    // Exibe o loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Faz o login no Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      // Fecha o diálogo de loading PRIMEIRO, antes que o AuthState mude a tela
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      // Fecha o diálogo de loading em caso de erro também
      Navigator.pop(context);
      
      showAlert(switch (e.code) {
        'invalid-email' => 'Email inválido.',
        'invalid-credential' => 'Email ou senha incorretos.',
        _ => 'Não foi possível entrar. Tente novamente. ${e.code}',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Lottie.asset(
                  'assets/animations/bill.json',
                  height: 150,
                  repeat: true,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bem-vindo de volta!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),
                MyTextField(
                  controller: emailController,
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 15),
                MyTextField(
                  controller: passwordController,
                  hintText: 'Senha',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                TextButton(
                  onPressed: forgotPassword,
                  child: const Text('Esqueceu a senha?'),
                ),
                MyButton(onTap: signIn, text: 'Entrar', icon: Icons.login),
                const SizedBox(height: 25),
                const Text('ou continue com'),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      SocialButton(
                        icon: Icons.g_mobiledata,
                        label: 'Google',
                        onTap: () {signInWithGoogle(context);},
                      ),
                      const SizedBox(width: 12),
                      SocialButton(
                        icon: Icons.apple,
                        label: 'Apple',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text('Registre-se agora'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}