import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../services/app_store.dart';

/// Transactions screen opened from More — searchable, filterable history.
/// Read-only: editing stays in Home/Add-sheet to keep one source of truth.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  String _filter = 'all'; // all | expense | income
  List<TransactionModel> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = AppStore();
    final txs = await store.getTransactions();
    if (!mounted) return;
    setState(() {
      _all = txs;
      _loading = false;
    });
  }

  List<TransactionModel> get _filtered {
    final q = _search.text.toLowerCase().trim();
    return _all.where((t) {
      if (_filter == 'expense' && t.type != TransactionType.expense) return false;
      if (_filter == 'income' && t.type != TransactionType.income) return false;
      if (q.isEmpty) return true;
      return (t.note ?? '').toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.amount.toString().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filtered;
    final df = DateFormat('d MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search notes, categories or amounts…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                for (final f in const [('all', 'All'), ('expense', 'Expenses'), ('income', 'Income')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text('No matching transactions',
                            style: TextStyle(color: AppColors.textSecondary(isDark))))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final t = list[i];
                          final isExpense = t.type == TransactionType.expense;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 19,
                              backgroundColor:
                                  (isExpense ? AppColors.accentRed : AppColors.primaryGreen)
                                      .withValues(alpha: 0.14),
                              child: Icon(
                                isExpense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                                size: 18,
                                color: isExpense ? AppColors.accentRed : AppColors.primaryGreen,
                              ),
                            ),
                            title: Text(
                              t.note?.isNotEmpty == true ? t.note! : t.category,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('${t.category} · ${df.format(t.date)}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark))),
                            trailing: Text(
                              '${isExpense ? '−' : '+'}₹${t.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isExpense ? AppColors.accentRed : AppColors.primaryGreen,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
