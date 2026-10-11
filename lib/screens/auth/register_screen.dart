import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_account.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

/// Registration screen — collects every field required by the app's access
/// policy: email, password, country, city, institution, professional vs.
/// student status, specialty and phone number.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  OccupationType _occupation = OccupationType.professional;
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _institutionCtrl.dispose();
    _specialtyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await context.read<AuthService>().register(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      country: _countryCtrl.text,
      city: _cityCtrl.text,
      institution: _institutionCtrl.text,
      occupation: _occupation,
      specialty: _specialtyCtrl.text,
      phoneNumber: _phoneCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
    if (err == null && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
        validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "L'accès à Genome Analyzer nécessite la création d'un compte",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      _emailCtrl,
                      'Adresse e-mail',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
                    ),
                    _field(
                      _passwordCtrl,
                      'Mot de passe',
                      Icons.lock_outline,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
                    ),
                    _field(
                      _confirmCtrl,
                      'Confirmer le mot de passe',
                      Icons.lock_outline,
                      obscure: _obscure,
                    ),
                    _field(_countryCtrl, 'Pays', Icons.flag_outlined),
                    _field(_cityCtrl, 'Ville', Icons.location_city_outlined),
                    _field(_institutionCtrl, 'Institution', Icons.school_outlined),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
                            const SizedBox(width: 10),
                            const Text('Statut :', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<OccupationType>(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: const Text('Professionnel', style: TextStyle(fontSize: 12.5)),
                                      value: OccupationType.professional,
                                      groupValue: _occupation,
                                      onChanged: (v) => setState(() => _occupation = v!),
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<OccupationType>(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: const Text('Étudiant', style: TextStyle(fontSize: 12.5)),
                                      value: OccupationType.student,
                                      groupValue: _occupation,
                                      onChanged: (v) => setState(() => _occupation = v!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _field(_specialtyCtrl, 'Spécialité', Icons.science_outlined),
                    _field(
                      _phoneCtrl,
                      'Numéro de téléphone',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Créer mon compte'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
