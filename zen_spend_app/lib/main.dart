import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const ZenSpendApp());
}

class ZenSpendApp extends StatelessWidget {
  const ZenSpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => TransactionRepository(),
      child: BlocProvider(
        create: (context) => TransactionBloc(context.read<TransactionRepository>())..add(LoadTransactions()),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Zen Spend',
          theme: AppTheme.theme,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

class AppTheme {
  static const bg = Color(0xFF0A0614);
  static const card = Color(0xFF171225);
  static const card2 = Color(0xFF211933);
  static const lime = Color(0xFFB6FF5C);
  static const pink = Color(0xFFFF4FD8);
  static const blue = Color(0xFF58D7FF);
  static const orange = Color(0xFFFFB44F);
  static const purple = Color(0xFF8E6CFF);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: lime, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: lime, width: 1.5)),
        ),
      );
}

class MoneyTransaction {
  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String note;

  const MoneyTransaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) => MoneyTransaction(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? 'Transaction',
        category: json['category']?.toString() ?? 'Other',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        isIncome: json['isIncome'] == true,
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        note: json['note']?.toString() ?? '',
      );
}

class TransactionRepository {
  static const _storageKey = 'zen_spend_transactions_v1';
  final _uuid = const Uuid();

  Future<List<MoneyTransaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      final list = jsonDecode(saved) as List<dynamic>;
      return list.map((e) => MoneyTransaction.fromJson(e as Map<String, dynamic>)).toList();
    }
    final fromApi = await _fetchStarterTransactions();
    await saveTransactions(fromApi);
    return fromApi;
  }

  Future<void> saveTransactions(List<MoneyTransaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(transactions.map((e) => e.toJson()).toList()));
  }

  Future<List<MoneyTransaction>> _fetchStarterTransactions() async {
    try {
      final response = await http.get(Uri.parse('https://dummyjson.com/products?limit=12'));
      if (response.statusCode != 200) throw Exception('Backend error');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List<dynamic>;
      final categories = ['Food', 'Shopping', 'Transport', 'Beauty', 'Study', 'Cafe'];
      return products.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value as Map<String, dynamic>;
        final isIncome = i == 0 || i == 6;
        return MoneyTransaction(
          id: _uuid.v4(),
          title: isIncome ? 'Part-time income' : item['title'].toString(),
          category: isIncome ? 'Salary' : categories[i % categories.length],
          amount: isIncome ? 300 + i * 40 : ((item['price'] as num).toDouble() + 5),
          isIncome: isIncome,
          date: DateTime.now().subtract(Duration(days: i + 1)),
          note: isIncome ? 'Example income loaded at first start.' : 'Example purchase loaded from DummyJSON backend.',
        );
      }).toList();
    } catch (_) {
      return [
        MoneyTransaction(id: _uuid.v4(), title: 'Coffee with friends', category: 'Cafe', amount: 7.5, isIncome: false, date: DateTime.now(), note: 'Fallback example'),
        MoneyTransaction(id: _uuid.v4(), title: 'Scholarship', category: 'Salary', amount: 250, isIncome: true, date: DateTime.now(), note: 'Fallback example'),
      ];
    }
  }
}

abstract class TransactionEvent {}
class LoadTransactions extends TransactionEvent {}
class AddTransaction extends TransactionEvent { final MoneyTransaction transaction; AddTransaction(this.transaction); }
class UpdateTransaction extends TransactionEvent { final MoneyTransaction transaction; UpdateTransaction(this.transaction); }
class DeleteTransaction extends TransactionEvent { final String id; DeleteTransaction(this.id); }
class SearchTransactions extends TransactionEvent { final String query; SearchTransactions(this.query); }
class FilterTransactions extends TransactionEvent { final String filter; FilterTransactions(this.filter); }

class TransactionState {
  final bool loading;
  final List<MoneyTransaction> all;
  final List<MoneyTransaction> visible;
  final String query;
  final String filter;
  final String? error;

  const TransactionState({required this.loading, required this.all, required this.visible, required this.query, required this.filter, this.error});
  factory TransactionState.initial() => const TransactionState(loading: true, all: [], visible: [], query: '', filter: 'All');

  TransactionState copyWith({bool? loading, List<MoneyTransaction>? all, List<MoneyTransaction>? visible, String? query, String? filter, String? error}) {
    return TransactionState(
      loading: loading ?? this.loading,
      all: all ?? this.all,
      visible: visible ?? this.visible,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      error: error,
    );
  }
}

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository repository;
  TransactionBloc(this.repository) : super(TransactionState.initial()) {
    on<LoadTransactions>(_load);
    on<AddTransaction>(_add);
    on<UpdateTransaction>(_update);
    on<DeleteTransaction>(_delete);
    on<SearchTransactions>((e, emit) => emit(_apply(state.copyWith(query: e.query))));
    on<FilterTransactions>((e, emit) => emit(_apply(state.copyWith(filter: e.filter))));
  }

  Future<void> _load(LoadTransactions event, Emitter<TransactionState> emit) async {
    emit(state.copyWith(loading: true));
    final list = await repository.loadTransactions();
    emit(_apply(state.copyWith(loading: false, all: _sort(list), visible: _sort(list))));
  }

  Future<void> _add(AddTransaction event, Emitter<TransactionState> emit) async {
    final updated = _sort([event.transaction, ...state.all]);
    await repository.saveTransactions(updated);
    emit(_apply(state.copyWith(all: updated)));
  }

  Future<void> _update(UpdateTransaction event, Emitter<TransactionState> emit) async {
    final updated = state.all.map((e) => e.id == event.transaction.id ? event.transaction : e).toList();
    await repository.saveTransactions(updated);
    emit(_apply(state.copyWith(all: _sort(updated))));
  }

  Future<void> _delete(DeleteTransaction event, Emitter<TransactionState> emit) async {
    final updated = state.all.where((e) => e.id != event.id).toList();
    await repository.saveTransactions(updated);
    emit(_apply(state.copyWith(all: updated)));
  }

  TransactionState _apply(TransactionState current) {
    var list = current.all;
    if (current.filter == 'Income') list = list.where((e) => e.isIncome).toList();
    if (current.filter == 'Expense') list = list.where((e) => !e.isIncome).toList();
    if (current.query.trim().isNotEmpty) {
      final q = current.query.toLowerCase();
      list = list.where((e) => e.title.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)).toList();
    }
    return current.copyWith(visible: _sort(list));
  }

  List<MoneyTransaction> _sort(List<MoneyTransaction> list) {
    final copy = [...list];
    copy.sort((a, b) => b.date.compareTo(a.date));
    return copy;
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.lime,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
        onPressed: () => showTransactionForm(context),
      ),
      body: SafeArea(
        child: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            if (state.loading) return const Center(child: CircularProgressIndicator());
            final income = state.all.where((e) => e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
            final expense = state.all.where((e) => !e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
            final balance = income - expense;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: HeroHeader(balance: balance, income: income, expense: expense)),
                SliverToBoxAdapter(child: Controls(state: state)),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Your money moves', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text('${state.visible.length} items', style: const TextStyle(color: Colors.white54)),
                  ]),
                )),
                if (state.visible.isEmpty)
                  const SliverToBoxAdapter(child: EmptyView())
                else
                  SliverList.builder(
                    itemCount: state.visible.length,
                    itemBuilder: (context, index) => TransactionCard(transaction: state.visible[index]),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class HeroHeader extends StatelessWidget {
  final double balance, income, expense;
  const HeroHeader({super.key, required this.balance, required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Zen Spend', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
            Text('Track it. Save it. Slay it.', style: TextStyle(color: Colors.white60)),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.card2, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.lime),
          ),
        ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB6FF5C), Color(0xFFFF4FD8), Color(0xFF58D7FF)],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current balance', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(money(balance), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: StatPill(title: 'Income', value: money(income), color: AppTheme.lime, icon: Icons.south_west_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StatPill(title: 'Expense', value: money(expense), color: AppTheme.pink, icon: Icons.north_east_rounded)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class StatPill extends StatelessWidget {
  final String title, value;
  final Color color;
  final IconData icon;
  const StatPill({super.key, required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        CircleAvatar(radius: 17, backgroundColor: color.withValues(alpha: .18), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        ])),
      ]),
    );
  }
}

class Controls extends StatelessWidget {
  final TransactionState state;
  const Controls({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(children: [
        TextField(
          onChanged: (v) => context.read<TransactionBloc>().add(SearchTransactions(v)),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search purchase, category...'),
        ),
        const SizedBox(height: 12),
        Row(children: ['All', 'Income', 'Expense'].map((f) {
          final selected = state.filter == f;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => context.read<TransactionBloc>().add(FilterTransactions(f)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.lime : AppTheme.card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(child: Text(f, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w900))),
                ),
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

class TransactionCard extends StatelessWidget {
  final MoneyTransaction transaction;
  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? AppTheme.lime : AppTheme.pink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Dismissible(
        key: ValueKey(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(26)),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) => confirmDelete(context),
        onDismissed: (_) => context.read<TransactionBloc>().add(DeleteTransaction(transaction.id)),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(transaction: transaction))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: .05))),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                child: Icon(iconFor(transaction.category, transaction.isIncome), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${transaction.category} • ${DateFormat('dd MMM yyyy').format(transaction.date)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${transaction.isIncome ? '+' : '-'}${money(transaction.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final MoneyTransaction transaction;
  const DetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? AppTheme.lime : AppTheme.pink;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => showTransactionForm(context, existing: transaction)),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: () async {
              final ok = await confirmDelete(context);
              if (ok == true && context.mounted) {
                context.read<TransactionBloc>().add(DeleteTransaction(transaction.id));
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(colors: [color.withValues(alpha: .40), AppTheme.card2, AppTheme.card]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 34, backgroundColor: color.withValues(alpha: .15), child: Icon(iconFor(transaction.category, transaction.isIncome), color: color, size: 36)),
              const SizedBox(height: 18),
              Text(transaction.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('${transaction.isIncome ? '+' : '-'}${money(transaction.amount)}', style: TextStyle(fontSize: 42, color: color, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 18),
          DetailRow(title: 'Category', value: transaction.category),
          DetailRow(title: 'Type', value: transaction.isIncome ? 'Income' : 'Expense'),
          DetailRow(title: 'Date', value: DateFormat('EEEE, dd MMMM yyyy').format(transaction.date)),
          const SizedBox(height: 16),
          const Text('Note', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(transaction.note.isEmpty ? 'No note added.' : transaction.note, style: const TextStyle(color: Colors.white70, height: 1.5)),
        ]),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final String title, value;
  const DetailRow({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(color: Colors.white54)),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(children: [
        const Icon(Icons.wallet_rounded, size: 70, color: AppTheme.purple),
        const SizedBox(height: 12),
        const Text('No transactions here', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Add your first purchase or income.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        ElevatedButton.icon(onPressed: () => showTransactionForm(context), icon: const Icon(Icons.add), label: const Text('Add transaction')),
      ]),
    );
  }
}

Future<bool?> confirmDelete(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.card,
      title: const Text('Delete transaction?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
}

void showTransactionForm(BuildContext context, {MoneyTransaction? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<TransactionBloc>(),
      child: TransactionForm(existing: existing),
    ),
  );
}

class TransactionForm extends StatefulWidget {
  final MoneyTransaction? existing;
  const TransactionForm({super.key, this.existing});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController noteController;
  late bool isIncome;
  late String category;
  late DateTime date;

  final expenseCategories = ['Food', 'Shopping', 'Transport', 'Beauty', 'Study', 'Cafe', 'Rent', 'Other'];
  final incomeCategories = ['Salary', 'Gift', 'Cashback', 'Scholarship', 'Other'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    titleController = TextEditingController(text: e?.title ?? '');
    amountController = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    noteController = TextEditingController(text: e?.note ?? '');
    isIncome = e?.isIncome ?? false;
    category = e?.category ?? 'Food';
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = isIncome ? incomeCategories : expenseCategories;
    if (!categories.contains(category)) category = categories.first;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: const BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 18),
              Text(widget.existing == null ? 'Add money move' : 'Edit money move', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: typeButton('Expense', !isIncome, AppTheme.pink, () => setState(() { isIncome = false; category = expenseCategories.first; }))),
                const SizedBox(width: 10),
                Expanded(child: typeButton('Income', isIncome, AppTheme.lime, () => setState(() { isIncome = true; category = incomeCategories.first; }))),
              ]),
              const SizedBox(height: 14),
              TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Title', hintText: 'Example: New hoodie'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', hintText: 'Example: 25.50'),
                validator: (v) {
                  final amount = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: AppTheme.card,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => category = v ?? categories.first),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(22)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Date', style: TextStyle(color: Colors.white70)),
                    Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: noteController, maxLines: 3, decoration: const InputDecoration(labelText: 'Note', hintText: 'Optional comment')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: save,
                  child: Text(widget.existing == null ? 'Save transaction' : 'Update transaction', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget typeButton(String text, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: selected ? color : AppTheme.card, borderRadius: BorderRadius.circular(20)),
        child: Center(child: Text(text, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w900))),
      ),
    );
  }

  void save() {
    if (!_formKey.currentState!.validate()) return;
    final transaction = MoneyTransaction(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: titleController.text.trim(),
      category: category,
      amount: double.parse(amountController.text.trim().replaceAll(',', '.')),
      isIncome: isIncome,
      date: date,
      note: noteController.text.trim(),
    );
    final bloc = context.read<TransactionBloc>();
    if (widget.existing == null) {
      bloc.add(AddTransaction(transaction));
    } else {
      bloc.add(UpdateTransaction(transaction));
    }
    Navigator.pop(context);
  }
}

IconData iconFor(String category, bool isIncome) {
  if (isIncome) return Icons.trending_up_rounded;
  switch (category) {
    case 'Food': return Icons.fastfood_rounded;
    case 'Shopping': return Icons.shopping_bag_rounded;
    case 'Transport': return Icons.directions_bus_rounded;
    case 'Beauty': return Icons.face_retouching_natural_rounded;
    case 'Study': return Icons.school_rounded;
    case 'Cafe': return Icons.local_cafe_rounded;
    case 'Rent': return Icons.home_rounded;
    default: return Icons.payments_rounded;
  }
}

String money(double value) => NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(value.abs());
