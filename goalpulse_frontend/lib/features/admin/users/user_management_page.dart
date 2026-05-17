import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/toast_notification.dart';
import '../../../widgets/loading_skeleton.dart';
import '../admin_provider.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = '';
  int _page = 1;
  bool _isLoading = false;
  List<AdminUser> _users = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(adminApiProvider).getUsers(
            search: _searchCtrl.text,
            role: _roleFilter,
            page: _page,
          );
      final list = (data['users'] as List<dynamic>? ?? [])
          .map((j) => AdminUser.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() {
        _users = list;
        _total = data['total'] as int? ?? 0;
      });
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Failed to load users: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      pageTitle: 'User Management',
      role: UserRole.admin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                // Search.
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email or department…',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.kTextSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.kTextSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.kBorder.withValues(alpha: 0.5)),
                      ),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Role filter.
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _roleFilter.isEmpty ? null : _roleFilter,
                    hint: Text('All Roles',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.kTextSecondary)),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.kBorder.withValues(alpha: 0.5)),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Roles')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                          value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(
                          value: 'employee', child: Text('Employee')),
                    ],
                    onChanged: (v) {
                      setState(() => _roleFilter = v ?? '');
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showUserDialog(null),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kBrandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // ── Table ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: LoadingSkeletonTable(),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Text('No users found.',
                            style: GoogleFonts.inter(
                                color: AppColors.kTextSecondary)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                AppColors.kNeutral100),
                            headingTextStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.kTextSecondary),
                            dataTextStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.kTextPrimary),
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Department')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _users.map((u) {
                              return DataRow(cells: [
                                DataCell(Text(u.displayName.isNotEmpty
                                    ? u.displayName
                                    : '—')),
                                DataCell(Text(u.email)),
                                DataCell(_roleBadge(u.role)),
                                DataCell(Text(
                                    u.department.isNotEmpty
                                        ? u.department
                                        : '—')),
                                DataCell(_statusBadge(u.isActive)),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.kBrandPrimary),
                                  tooltip: 'Edit user',
                                  onPressed: () => _showUserDialog(u),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),

          // ── Pagination ────────────────────────────────────────────────
          if (!_isLoading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Showing ${_users.length} of $_total users',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.kTextSecondary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    child: const Text('← Prev'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Page $_page',
                        style: GoogleFonts.inter(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: _users.length == 20
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                    child: const Text('Next →'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final colors = {
      'admin': AppColors.kDanger,
      'manager': AppColors.kBrandSecondary,
      'employee': AppColors.kBrandPrimary,
    };
    final c = colors[role] ?? AppColors.kTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5)),
      child: Text(role[0].toUpperCase() + role.substring(1),
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? AppColors.kSuccess : AppColors.kTextSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(isActive ? 'Active' : 'Inactive',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: isActive
                    ? AppColors.kSuccess
                    : AppColors.kTextSecondary)),
      ],
    );
  }

  void _showUserDialog(AdminUser? user) {
    showDialog(
      context: context,
      builder: (_) => _UserDialog(
        user: user,
        allUsers: _users,
        onSaved: _load,
      ),
    );
  }
}

// ── User Dialog ───────────────────────────────────────────────────────────────

class _UserDialog extends ConsumerStatefulWidget {
  const _UserDialog(
      {required this.user, required this.allUsers, required this.onSaved});
  final AdminUser? user;
  final List<AdminUser> allUsers;
  final VoidCallback onSaved;

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _designCtrl;
  late final TextEditingController _passCtrl;
  String _role = 'employee';
  String? _managerId;
  bool _isActive = true;
  bool _isSaving = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.displayName ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _deptCtrl = TextEditingController(text: u?.department ?? '');
    _designCtrl = TextEditingController(text: u?.designation ?? '');
    _passCtrl = TextEditingController();
    _role = u?.role ?? 'employee';
    _managerId = u?.managerId;
    _isActive = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _deptCtrl.dispose();
    _designCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final managers = widget.allUsers
        .where((u) => u.role == 'manager' || u.role == 'admin')
        .toList();

    return AlertDialog(
      title: Text(_isEdit ? 'Edit User' : 'Add User',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Display Name *', _nameCtrl,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _field('Email *', _emailCtrl,
                    readOnly: _isEdit,
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Valid email required' : null),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  _field('Password *', _passCtrl,
                      obscure: true,
                      validator: (v) => v == null || v.length < 6
                          ? 'Min 6 characters'
                          : null),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: _dec('Role'),
                  items: const [
                    DropdownMenuItem(
                        value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(
                        value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'employee'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _managerId,
                  decoration: _dec('Manager (optional)'),
                  hint: const Text('No manager'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('None')),
                    ...managers.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.displayName.isNotEmpty
                            ? m.displayName
                            : m.email))),
                  ],
                  onChanged: (v) => setState(() => _managerId = v),
                ),
                const SizedBox(height: 12),
                _field('Department', _deptCtrl),
                const SizedBox(height: 12),
                _field('Designation', _designCtrl),
                const SizedBox(height: 12),
                if (_isEdit)
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: Text('Active',
                        style: GoogleFonts.inter(fontSize: 14)),
                    activeThumbColor: AppColors.kSuccess,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrandPrimary,
              foregroundColor: Colors.white),
          child: Text(_isSaving
              ? 'Saving…'
              : (_isEdit ? 'Save Changes' : 'Create User')),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final api = ref.read(adminApiProvider);
    try {
      final data = {
        'display_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role,
        'manager_id': _managerId,
        'department': _deptCtrl.text.trim(),
        'designation': _designCtrl.text.trim(),
        'is_active': _isActive,
        if (!_isEdit) 'password': _passCtrl.text,
      };
      if (_isEdit) {
        await api.updateUser(widget.user!.id, data);
      } else {
        await api.createUser(data);
      }
      if (mounted) {
        Navigator.pop(context);
        ToastNotification.showSuccess(
            context,
            _isEdit ? 'User updated.' : 'User created.');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool readOnly = false,
      bool obscure = false,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      obscureText: obscure,
      validator: validator,
      decoration: _dec(label),
      style: GoogleFonts.inter(fontSize: 13),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 13, color: AppColors.kTextSecondary),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
