import 'package:flutter/material.dart';
import '../models/account.dart';

/// Picks which account money came from or went to. Only shown once the user
/// has created an account.
class AccountField extends StatelessWidget {
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;

  const AccountField({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.label = 'Account',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('No account')),
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Row(
              children: [
                Icon(a.type.icon, size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
