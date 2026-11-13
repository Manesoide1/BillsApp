import 'dart:convert';
import 'dart:io';
import 'package:apk_auth/view/home_page.dart';
import 'package:apk_auth/view/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late final TextEditingController nameController;
  File? _selectedImage;    // Armazena a foto escolhida localmente (para visualização)
  String? _imageBase64;    // Armazena a string Base64 que será salva no Firestore

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

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _imageBase64 = doc.data()?['photoBase64'];
        });
      }
    } catch (e) {
      print('Erro ao carregar dados do Firestore: $e');
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
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 40);
    
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

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            updateData,
            SetOptions(merge: true),
          );

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

  Future<void> delete() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      
      if (!mounted) return;
      Navigator.pop(context); 
      Navigator.pop(context); 
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showAlert(switch (e.code) {
        'requires-recent-login' => 'Você precisa fazer login novamente para deletar sua conta.',
        _ => 'Não foi possível deletar a conta. Tente novamente.',
      });
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
                              ? MemoryImage(base64Decode(_imageBase64!)) as ImageProvider
                              : null),
                      child: (_selectedImage == null && (_imageBase64 == null || _imageBase64!.isEmpty))
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
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
              MyButton(
                onTap: update,
                text: 'Atualizar',
                icon: Icons.update,
              ),
              const SizedBox(height: 25),
              MyButton(
                onTap: () async {
                  FocusScope.of(context).unfocus(); // Fecha o teclado se estiver aberto

                  await FirebaseAuth.instance.signOut();

                  if (!mounted) return; // Garante que o widget ainda está na árvore antes de navegar

                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                text: 'Sair da conta',
                icon: Icons.logout,
              ),
              const SizedBox(height: 25),
              TextButton(
                onPressed: delete,
                child: const Text(
                  'Deletar conta',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            // Lógica para Filtrar
          } else if (index == 2) {
            // Já estamos na UserPage
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Filtrar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}