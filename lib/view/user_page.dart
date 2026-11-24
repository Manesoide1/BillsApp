import 'dart:convert';
import 'dart:io';

import 'package:bills_app/components/my_botton_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bills_app/view/auth_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late final TextEditingController nameController;
  File?
  _selectedImage; // Armazena a foto escolhida localmente (para visualização)
  String? _imageBase64; // Armazena a string Base64 que será salva no Firestore

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    nameController = TextEditingController(text: user?.displayName ?? '');
    _loadUserData();
  }

  // Busca os dados adicionais (como a foto em Base64) do Firestore ao abrir a página
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _imageBase64 = doc.data()?['photoBase64'];
        });
      }
    } catch (e) {
      showAlert('Erro ao carregar dados do Firestore: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
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

  // Função para escolher a imagem e convertê-la em Base64 compactado
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 40,
    );

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);

      setState(() {
        _selectedImage = imageFile;
        _imageBase64 = base64String;
      });
    }
  }

  // Exibe um modal para o usuário escolher entre Câmera e Galeria
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> update() async {
    if (nameController.text.trim().isEmpty) {
      showAlert('O nome não pode ficar vazio!');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await user.updateDisplayName(nameController.text.trim());

      Map<String, dynamic> updateData = {
        'name': nameController.text.trim(),
        'email': user.email,
      };

      if (_imageBase64 != null) {
        updateData['photoBase64'] = _imageBase64;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context); // fecha o loading
      showAlert('Perfil atualizado com sucesso!');

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showAlert('Não foi possível atualizar. Tente novamente.');
    }
  }

  // 1. Pergunta inicial de confirmação antes de iniciar o processo de exclusão
  void _confirmarPrimeiraExclusao() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenção'),
        content: const Text(
          'Tem certeza de que deseja deletar sua conta? Todos os seus dados e contas cadastradas serão perdidos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context); // Fecha o diálogo de aviso
              delete(); // Inicia o processo de exclusão
            },
            child: const Text(
              'Sim, quero deletar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Função para solicitar a senha e reautenticar antes de apagar
  void _mostrarDialogoReautenticacao() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Por segurança, digite sua senha atual para confirmar a exclusão da conta:',
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha atual',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context); // Fecha o diálogo de senha

                // Executa a reautenticação e deleção
                await _reautenticarEDeletar(passwordController.text.trim());
              },
              child: const Text(
                'Confirmar e Apagar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reautenticarEDeletar(String password) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email;

      if (email == null) {
        Navigator.pop(context);
        showAlert('Erro: E-mail do usuário não encontrado.');
        return;
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();

      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context); // Fecha o loading

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Conta Deletada'),
          content: const Text('Sua conta foi deletada com sucesso.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fecha o loading
      showAlert(
        'Senha incorreta ou erro ao reautenticar. A conta não foi apagada.',
      );
    }
  }

  Future<void> delete() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();

      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context); // Fecha o loading

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Conta Deletada'),
          content: const Text('Sua conta foi deletada com sucesso.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fecha o loading de tentativa inicial

      if (e.code == 'requires-recent-login') {
        _mostrarDialogoReautenticacao();
      } else {
        showAlert('Não foi possível deletar a conta. Tente novamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Seu perfil'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!) as ImageProvider
                          : (_imageBase64 != null && _imageBase64!.isNotEmpty
                                ? MemoryImage(base64Decode(_imageBase64!))
                                      as ImageProvider
                                : null),
                      child:
                          (_selectedImage == null &&
                              (_imageBase64 == null || _imageBase64!.isEmpty))
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D9488),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              MyTextField(
                controller: nameController,
                hintText: 'Nome completo',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 25),
              MyButton(onTap: update, text: 'Atualizar', icon: Icons.update),
              const SizedBox(height: 25),
              MyButton(
                onTap: () async {
                  FocusScope.of(context).unfocus();

                  // Encerra também a sessão do Google caso o usuário tenha entrado com conta Google
                  try {
                    await GoogleSignIn.instance.signOut();
                  } catch (_) {}

                  await FirebaseAuth.instance.signOut();

                  if (!mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                    (route) => false,
                  );
                },
                text: 'Sair da conta',
                icon: Icons.logout,
              ),
              const SizedBox(height: 25),
              TextButton(
                onPressed: _confirmarPrimeiraExclusao, // Aciona o alerta inicial de confirmação
                child: const Text(
                  'Deletar conta',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MyBottomNav(
        currentIndex: 2, // Perfil
        onFilterTap: null, // Não há ação de filtro nesta página
      ),
    );
  }
}
