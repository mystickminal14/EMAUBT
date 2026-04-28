import 'package:ema_app/utils/utils.dart';
import 'package:ema_app/view_model/auth_view_model/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final RegExp _phoneRegex = RegExp(r'^[0-9]{10}$');

  final Logger _logger = Logger();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      _logger.d('Opening image picker...');
      if (Platform.isWindows) {
        FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _imageFile = File(result.files.single.path!);
          });
          _logger.d('Picked image (windows): ${_imageFile?.path}');
        } else {
          _logger.d('No image picked (windows).');
        }
      } else {
        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _imageFile = File(pickedFile.path);
          });
          _logger.d('Picked image: ${_imageFile?.path}');
        } else {
          _logger.d('No image picked.');
        }
      }
    } catch (e, st) {
      _logger.e('Error picking image', error: e, stackTrace: st);
      print('Error picking image: $e');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed.');
      return;
    }

    if (_imageFile == null) {
      Utils.flushBarErrorMessage("Please select a profile image.", context);
      return;
    }

    final Map<String, dynamic> fields = {
      'full_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'password': _passwordController.text,
    };

    _logger.d('Starting registration with fields: $fields, image: ${_imageFile?.path}');

    await Provider.of<AuthViewModel>(context, listen: false)
        .register(fields, _imageFile!, context);
  }

  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        return Scaffold(
          appBar: AppBar(title: const Text("Register")),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    "Create Your Account",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter your name';
                            if (value.trim().length < 2) return 'Name must be at least 2 characters';
                            if (value.trim().length > 100) return 'Name must be at most 100 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        // _imageFile == null
                        //     ? ElevatedButton(
                        //   onPressed: _pickImage,
                        //   child: const Text("Pick an Image"),
                        // )
                        //     : GestureDetector(
                        //   onTap: _pickImage,
                        //   child: CircleAvatar(
                        //     radius: 40,
                        //     backgroundImage: FileImage(_imageFile!),
                        //   ),
                        // ),
                        // const SizedBox(height: 20),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter your email';
                            final regex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!regex.hasMatch(value)) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: "Phone Number",
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                            counterText: "",
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter your phone';
                            if (!_phoneRegex.hasMatch(value)) return 'Enter a valid 10-digit number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: _togglePasswordVisibility,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter password';
                            if (value.length < 8) return 'At least 8 characters';
                            if (!RegExp(r'[A-Za-z]').hasMatch(value)) return 'Must contain a letter';
                            if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain a number';
                            if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) return 'Must contain a special character';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: _toggleConfirmPasswordVisibility,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Confirm your password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: authViewModel.isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: authViewModel.isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text('Register'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
