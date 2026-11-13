import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(content: Text(message)),
    );
  }

  Future<void> register() async {

    if (nameController.text.isEmpty || nameController.text.trim().split(RegExp(r'\s+')).length < 2) {
      showAlert('Digite seu nome completo!');
      return;
    }

    if (passwordController.text != confirmController.text) {
      showAlert('Senhas não conferem!');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      await FirebaseAuth.instance.currentUser!.updateDisplayName(nameController.text.trim());

      if (!mounted) return;
      Navigator.pop(context); // fecha o loading
      Navigator.pop(context); // fecha a RegisterPage
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showAlert(switch (e.code) {
        'email-already-in-use' => 'Já existe um usuário com esse email!',
        'invalid-email' => 'Email inválido!',
        'weak-password' => 'Escolha uma senha mais forte.',
        _ => 'Não foi possível cadastrar. Tente novamente.',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Crie sua conta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Lottie.asset(
                'assets/animations/profile_person.json',
                height: 150,
                repeat: false,
              ),
              MyTextField(
                controller: nameController,
                hintText: 'Nome Completo',
                icon: Icons.person_outline,
              ),
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
              const SizedBox(height: 15),
              MyTextField(
                controller: confirmController,
                hintText: 'Confirmar senha',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 25),
              MyButton(
                onTap: register,
                text: 'Registrar',
                icon: Icons.person_add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
