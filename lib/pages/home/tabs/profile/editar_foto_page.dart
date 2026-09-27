import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../controllers/user_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';

class EditarFotoPage extends StatefulWidget {
  const EditarFotoPage({super.key});

  @override
  State<EditarFotoPage> createState() => _EditarFotoPageState();
}

class _EditarFotoPageState extends State<EditarFotoPage> {
  File? _image;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      context.showError('Erro ao selecionar imagem: $e');
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 8.h),
                child: Text(
                  'Escolha uma opção',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5D201C),
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFFF6961)),
                title: const Text('Galeria de Fotos'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFFFF6961)),
                title: const Text('Tirar Foto agora'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Future<void> _savePhoto() async {
    if (_image == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<UserProvider>().atualizarFotoPerfil(_image!);

      if (!mounted) return;
      context.showSuccess('Foto de perfil atualizada com sucesso!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showError('Erro ao atualizar foto: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentFoto = userProvider.fotoPerfil;

    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: AppBar(
        backgroundColor: AppColors.fundo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D201C), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),
                      Text(
                        'Foto de Perfil',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C),
                          height: 1.2,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Escolha uma foto para o seu perfil neste aparelho.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade800,
                          height: 1.5,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 48.h),
                      Center(
                        child: GestureDetector(
                          onTap: _showPickerOptions,
                          child: Stack(
                            children: [
                              Container(
                                width: 160.r,
                                height: 160.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4.w),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5D201C).withValues(alpha: 0.1),
                                      blurRadius: 10.r,
                                      spreadRadius: 2.r,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _image != null
                                      ? Image.file(_image!, fit: BoxFit.cover)
                                      : (currentFoto != null && currentFoto.isNotEmpty
                                          ? (currentFoto.startsWith('http')
                                              ? Image.network(currentFoto, fit: BoxFit.cover)
                                              : Image.file(File(currentFoto), fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Icon(Icons.two_wheeler_rounded,
                                                    size: 72.r, color: AppColors.primaria)))
                                          : Container(
                                              color: Colors.white,
                                              child: Icon(
                                                Icons.two_wheeler_rounded,
                                                size: 72.r,
                                                color: AppColors.primaria,
                                              ),
                                            )),
                                ),
                              ),
                              Positioned(
                                bottom: 4.h,
                                right: 4.w,
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6961),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 22.r,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Center(
                        child: Text(
                          'Toque para mudar a foto',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF5D201C),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 32.h, top: 16.h),
              child: BotaoLargoNhac(
                texto: 'Salvar alterações',
                carregando: _isLoading,
                onPressed: (_image != null && !_isLoading) ? _savePhoto : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
