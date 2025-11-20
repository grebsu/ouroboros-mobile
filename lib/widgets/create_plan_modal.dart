
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

class CreatePlanModal extends StatefulWidget {
  final Plan? initialPlan;

  const CreatePlanModal({super.key, this.initialPlan});

  @override
  State<CreatePlanModal> createState() => _CreatePlanModalState();
}

class _CreatePlanModalState extends State<CreatePlanModal> {
  final _formKey = GlobalKey<FormState>();
  late String _planName;
  late String _cargo;
  late String _edital;
  late String _banca;
  late String _observations;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _planName = widget.initialPlan?.name ?? '';
    _cargo = widget.initialPlan?.cargo ?? '';
    _edital = widget.initialPlan?.edital ?? '';
    _banca = widget.initialPlan?.banca ?? '';
    _observations = widget.initialPlan?.observations ?? '';
    _selectedImagePath = widget.initialPlan?.iconUrl;
  }

  Future<void> _pickImage() async {
    PermissionStatus photoStatus = await Permission.photos.request();
    PermissionStatus storageStatus = await Permission.storage.request();

    if (photoStatus.isGranted || storageStatus.isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final String? pickedFilePath = result.files.single.path;
        if (pickedFilePath == null) return;

        try {
          // Read the image file
          final imageBytes = await File(pickedFilePath).readAsBytes();
          final image = img.decodeImage(imageBytes);

          if (image == null) {
            throw Exception('Could not decode image');
          }

          // Resize the image
          final resizedImage = img.copyResize(image, width: 512, height: 512);

          // Get the app's documents directory
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String appDocPath = appDocDir.path;
          final String fileName = const Uuid().v4() + '.png';
          final String newPath = '$appDocPath/$fileName';

          // Save the resized image
          final newImageFile = File(newPath);
          await newImageFile.writeAsBytes(img.encodePng(resizedImage));

          setState(() {
            _selectedImagePath = newImageFile.path;
          });
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao processar a imagem: $e')),
            );
          }
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de armazenamento negada. Não é possível importar a imagem.')),
        );
      }
    }
  }

  Future<void> _savePlan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final plansProvider = Provider.of<PlansProvider>(context, listen: false);
      final planningProvider = Provider.of<PlanningProvider>(context, listen: false); // Get PlanningProvider

      // Show a loading indicator while saving
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        },
      );

      try {
        if (widget.initialPlan == null) {
          // Create new plan
          final newPlan = await plansProvider.addPlan(
            name: _planName,
            cargo: _cargo,
            edital: _edital,
            banca: _banca,
            observations: _observations,
            iconUrl: _selectedImagePath, // Pass the selected image path
          );
          planningProvider.updateForPlan(newPlan.id);
        } else {
          // Update existing plan
          final updatedPlan = widget.initialPlan!.copyWith(
            name: _planName,
            cargo: _cargo,
            edital: _edital,
            banca: _banca,
            observations: _observations,
            iconUrl: _selectedImagePath, // Pass the selected image path
          );
          await plansProvider.updatePlan(updatedPlan);
        }

        // Pop the loading indicator
        Navigator.of(context, rootNavigator: true).pop();
        // Pop the create plan modal
        Navigator.of(context).pop();
      } catch (e) {
        // Pop the loading indicator
        Navigator.of(context, rootNavigator: true).pop();
        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar o plano: $e')),
        );
      }
    }
  }

  Widget _buildImageWidget() {
    if (_selectedImagePath != null && _selectedImagePath!.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            File(_selectedImagePath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading image with Image.file: $error');
              return const Icon(Icons.broken_image, color: Colors.grey, size: 48);
            },
          ),
        );
      } catch (e) {
        print('Exception when creating Image.file widget: $e');
        return const Icon(Icons.error, color: Colors.red, size: 48);
      }
    } else {
      return const Icon(Icons.camera_alt, color: Colors.grey, size: 48);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surfaceTint: Colors.transparent,
        ),
      ),
      child: AlertDialog(
        title: Text(widget.initialPlan == null ? 'Novo Plano' : 'Editar Plano'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image and 'Alterar Imagem' button
                Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: _buildImageWidget(),
                    ),
                    TextButton(
                      onPressed: _pickImage,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal,
                      ),
                      child: const Text('Importar Imagem'),
                    ),
                  ],
                ),
                const SizedBox(height: 24), // Spacing between image section and form fields
                // Form fields
                TextFormField(
                  initialValue: _planName,
                  decoration: InputDecoration(
                    labelText: 'NOME',
                    labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'O nome do plano não pode estar vazio.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _planName = value!;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _cargo,
                  decoration: InputDecoration(
                    labelText: 'CARGO (Opcional)',
                    labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
                    ),
                  ),
                  onSaved: (value) {
                    _cargo = value ?? '';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _edital,
                  decoration: InputDecoration(
                    labelText: 'EDITAL (Opcional)',
                    labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
                    ),
                  ),
                  onSaved: (value) {
                    _edital = value ?? '';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _banca,
                  decoration: InputDecoration(
                    labelText: 'BANCA (Opcional)',
                    labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
                    ),
                  ),
                  onSaved: (value) {
                    _banca = value ?? '';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _observations,
                  decoration: InputDecoration(
                    labelText: 'OBSERVAÇÕES (Opcional)',
                    labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
                    ),
                  ),
                  maxLines: 3,
                  onSaved: (value) {
                    _observations = value ?? '';
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal,
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _savePlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.initialPlan == null ? 'Avançar' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
