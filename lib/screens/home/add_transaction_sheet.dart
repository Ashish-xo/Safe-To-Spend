import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/transaction_model.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet to add an income/expense manually.
/// (The original Home screen had dead "+ Income"/"+ Expense" buttons.)
class AddTransactionSheet extends StatefulWidget {
  final bool isIncome;
  final VoidCallback onSaved;

  const AddTransactionSheet({super.key, required this.isIncome, required this.onSaved});

  static Future<void> show(BuildContext context, {required bool isIncome, required VoidCallback onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(isIncome: isIncome, onSaved: onSaved),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _category = 'food';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _expenseCats = ['food', 'transport', 'groceries', 'entertainment', 'shopping', 'health', 'education', 'rent', 'utilities', 'other'];
  static const _incomeCats = ['salary', 'freelance', 'pocket money', 'refund', 'other'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    setState(() => _saving = true);
    final store = AppStore();
    await store.addTransaction(TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: widget.isIncome ? TransactionType.income : TransactionType.expense,
      category: _category,
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    ));
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.isIncome ? _incomeCats : _expenseCats;
    if (!cats.contains(_category)) _category = cats.first;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isIncome ? 'Add Income' : 'Add Expense',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: widget.isIncome ? '+ ₹ ' : '- ₹ ',
              prefixStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: widget.isIncome ? AppColors.primaryGreen : AppColors.accentRed,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${_date.day}/${_date.month}/${_date.year}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
