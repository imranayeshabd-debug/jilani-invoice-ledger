import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const JilaniApp());

const company = 'মেসার্স জিলানী ফ্লাওয়ার মিল এন্ড ফুড প্রোডাক্টস';
const address = 'বিসিক শিল্পনগরী, কালিকা প্রসাদ, ভৈরব, কিশোরগঞ্জ';
String dateNow() => DateTime.now().toString().substring(0, 10);
double val(dynamic x) => x is num ? x.toDouble() : double.tryParse('$x') ?? 0;
String tk(double x) => x.toStringAsFixed(2);

class JilaniApp extends StatelessWidget {
  const JilaniApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Jilani Ledger',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0, invoiceNo = 1;
  bool ready = false;
  List<Map<String, dynamic>> parties = [],
      accounts = [{'name': 'Cash', 'kind': 'cash'}],
      accountRows = [];

  final banks = [
    'পূবালী ব্যাংক',
    'ইসলামী ব্যাংক',
    'ডাচ্-বাংলা ব্যাংক',
    'সোনালী ব্যাংক',
    'অগ্রণী ব্যাংক',
    'জনতা ব্যাংক'
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    parties = (jsonDecode(p.getString('parties2') ?? '[]') as List)
        .map((e) => Map<String, dynamic>.from(e)).toList();
    accounts = (jsonDecode(p.getString('accounts2') ??
        '[{"name":"Cash","kind":"cash"}]') as List)
        .map((e) => Map<String, dynamic>.from(e)).toList();
    accountRows = (jsonDecode(p.getString('accountRows2') ?? '[]') as List)
        .map((e) => Map<String, dynamic>.from(e)).toList();
    invoiceNo = p.getInt('invoiceNo2') ?? 1;
    if (mounted) setState(() => ready = true);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('parties2', jsonEncode(parties));
    await p.setString('accounts2', jsonEncode(accounts));
    await p.setString('accountRows2', jsonEncode(accountRows));
    await p.setInt('invoiceNo2', invoiceNo);
  }

  Map<String, dynamic>? findParty(String n) {
    for (final p in parties) {
      if ('${p['name']}'.toLowerCase().trim() ==
          n.toLowerCase().trim()) return p;
    }
    return null;
  }

  Map<String, dynamic> party(String n,
      {String phone = '', String addr = ''}) {
    final old = findParty(n);
    if (old != null) {
      if (phone.isNotEmpty) old['phone'] = phone;
      if (addr.isNotEmpty) old['address'] = addr;
      return old;
    }
    final p = {
      'name': n.trim(),
      'phone': phone,
      'address': addr,
      'rows': <Map<String, dynamic>>[]
    };
    parties.add(p);
    return p;
  }

  double receivable(Map<String, dynamic> p) {
    double b = 0;
    for (final r in (p['rows'] as List)) {
      if ((r['side'] ?? 'receivable') == 'receivable') {
        b += val(r['debit']) - val(r['credit']);
      }
    }
    return b;
  }

  double payable(Map<String, dynamic> p) {
    double b = 0;
    for (final r in (p['rows'] as List)) {
      if (r['side'] == 'payable') {
        b += val(r['credit']) - val(r['debit']);
      }
    }
    return b;
  }

  double accountBalance(String name) {
    double b = 0;
    for (final r in accountRows) {
      if (r['account'] == name) b += val(r['amount']);
    }
    return b;
  }

  void bankExists(String name) {
    if (name != 'Cash' &&
        !accounts.any((a) => a['name'] == name)) {
      accounts.add({'name': name, 'kind': 'bank'});
    }
  }

  void partyRow(Map<String, dynamic> p, String details,
      double debit, double credit, String method, String lf,
      {String side = 'receivable'}) {
    (p['rows'] as List).add({
      'date': dateNow(),
      'details': details,
      'debit': debit,
      'credit': credit,
      'method': method,
      'lf': lf,
      'side': side
    });
  }

  void accountRow(String name, double amount, String details) {
    accountRows.add({
      'date': dateNow(),
      'account': name,
      'amount': amount,
      'details': details
    });
  }

  Future<void> invoice(String name, String phone, String addr,
      List<Map<String, dynamic>> items, double paid, String account) async {
    final p = party(name, phone: phone, addr: addr);
    double total = 0;
    final lines = <String>[];
    for (final i in items) {
      final a = val(i['qty']) * val(i['rate']);
      total += a;
      lines.add('${i['name']} ${i['qty']}×${i['rate']}');
    }
    partyRow(p, 'বিক্রয়: ${lines.join(', ')}',
        total, 0, 'ইনভয়েস', '$invoiceNo');
    if (paid > 0) {
      bankExists(account);
      partyRow(p,
          '${account == 'Cash' ? 'ক্যাশ' : account} এর মাধ্যমে টাকা জমা',
          0, paid, account, '$invoiceNo');
      accountRow(account, paid, '${p['name']} থেকে ইনভয়েসের টাকা জমা');
    }
    invoiceNo++;
    await save();
    if (mounted) setState(() {});
  }

  Future<void> receive(Map<String, dynamic> p, double amount,
      String acc, String note) async {
    bankExists(acc);
    partyRow(p, note.isEmpty ? '$acc এর মাধ্যমে টাকা জমা' : note,
        0, amount, acc, '');
    accountRow(acc, amount, '${p['name']} থেকে টাকা গ্রহণ');
    await save();
    if (mounted) setState(() {});
  }

  Future<void> purchase(
      Map<String, dynamic> p, double amount, String note) async {
    partyRow(p, note.isEmpty ? 'পণ্য ক্রয়' : note,
        0, amount, 'ক্রয়', '', side: 'payable');
    await save();
    if (mounted) setState(() {});
  }

  Future<void> pay(Map<String, dynamic> p, double amount,
      String acc, String note) async {
    bankExists(acc);
    partyRow(p, note.isEmpty ? '$acc এর মাধ্যমে পেমেন্ট' : note,
        amount, 0, acc, '', side: 'payable');
    accountRow(acc, -amount, '${p['name']} কে পেমেন্ট');
    await save();
    if (mounted) setState(() {});
  }

  Future<void> movement(
      String acc, double amount, String note, bool deposit) async {
    bankExists(acc);
    accountRow(acc, deposit ? amount : -amount, note);
    await save();
    if (mounted) setState(() {});
  }

  List<String> get accountNames =>
      accounts.map((a) => '${a['name']}').toList();

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      dashboard(),
      InvoiceForm(
          no: invoiceNo,
          accounts: [
            ...accountNames,
            ...banks.where((b) => !accountNames.contains(b))
          ],
          onSave: invoice),
      partyList(),
      accountList()
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('জিলানী ইনভয়েস ও খতিয়ান'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: pages[tab],
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(
              onPressed: addParty,
              icon: const Icon(Icons.person_add),
              label: const Text('পার্টি যোগ'))
          : tab == 3
              ? FloatingActionButton.extended(
                  onPressed: movementDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('লেনদেন'))
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home), label: 'হোম'),
          NavigationDestination(
              icon: Icon(Icons.receipt), label: 'ইনভয়েস'),
          NavigationDestination(
              icon: Icon(Icons.people), label: 'পার্টি'),
          NavigationDestination(
              icon: Icon(Icons.account_balance), label: 'ক্যাশ/ব্যাংক'),
        ],
      ),
    );
  }

  Widget dashboard() {
    final due = parties.fold<double>(0, (s, p) => s + receivable(p));
    final payableTotal =
        parties.fold<double>(0, (s, p) => s + payable(p));
    return ListView(padding: const EdgeInsets.all(14), children: [
      Container(
        color: Colors.indigo,
        padding: const EdgeInsets.all(14),
        child: const Column(children: [
          Text(company,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(address,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)),
        ]),
      ),
      info('মোট পার্টি', '${parties.length}'),
      info('মোট পাওনা', '${tk(due)} টাকা'),
      info('মোট দেনা', '${tk(payableTotal)} টাকা'),
      info('ক্যাশ ব্যালেন্স', '${tk(accountBalance('Cash'))} টাকা'),
      info('পরবর্তী ইনভয়েস', '$invoiceNo'),
    ]);
  }

  Widget info(String a, String b) => Card(
      child: ListTile(
          title: Text(a),
          trailing: Text(b,
              style: const TextStyle(fontWeight: FontWeight.bold))));

  Widget partyList() => parties.isEmpty
      ? const Center(child: Text('এখনো পার্টি যোগ করা হয়নি'))
      : ListView.builder(
          itemCount: parties.length,
          itemBuilder: (c, i) {
            final p = parties[i];
            final r = receivable(p);
            final d = payable(p);
            return Card(
              child: ListTile(
                title: Text('${p['name']}'),
                subtitle: Text(
                    '${p['phone'] ?? ''}\nআমাদের পাওনা: ${tk(r)} টাকা  |  আমাদের দেনা: ${tk(d)} টাকা'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PartyPage(
                        p: p,
                        accounts: [
                          ...accountNames,
                          ...banks.where(
                              (b) => !accountNames.contains(b))
                        ],
                        onReceive: (a, x, n) => receive(p, a, x, n),
                        onPurchase: (a, n) => purchase(p, a, n),
                        onPay: (a, x, n) => pay(p, a, x, n),
                      ),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            );
          },
        );

  void addParty() {
    final n = TextEditingController(),
        ph = TextEditingController(),
        ad = TextEditingController();
    showDialog(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('নতুন পার্টি'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: n,
                    decoration:
                        const InputDecoration(labelText: 'পার্টির নাম')),
                TextField(
                    controller: ph,
                    decoration:
                        const InputDecoration(labelText: 'মোবাইল')),
                TextField(
                    controller: ad,
                    decoration:
                        const InputDecoration(labelText: 'ঠিকানা')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('বাতিল')),
                ElevatedButton(
                    onPressed: () async {
                      if (n.text.trim().isEmpty ||
                          findParty(n.text) != null) return;
                      party(n.text, phone: ph.text, addr: ad.text);
                      await save();
                      if (mounted) setState(() {});
                      if (d.mounted) Navigator.pop(d);
                    },
                    child: const Text('সেভ'))
              ],
            ));
  }

  Widget accountList() => ListView(
        children: [
          ListTile(
            title: const Text('ক্যাশ'),
            trailing: Text('${tk(accountBalance('Cash'))} টাকা'),
          ),
          ...accounts.where((a) => a['kind'] == 'bank').map((a) {
            final name = '${a['name']}';
            return ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text(name),
              trailing: Text('${tk(accountBalance(name))} টাকা'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountPage(
                    name: name,
                    rows: accountRows
                        .where((r) => r['account'] == name)
                        .toList(),
                    balance: accountBalance(name),
                  ),
                ),
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'কোনো ব্যাংকে প্রথম লেনদেন হলে ব্যাংকটি তালিকায় যুক্ত হবে।'),
          ),
        ],
      );

  void movementDialog() {
    final amount = TextEditingController(),
        note = TextEditingController();
    String acc = 'Cash', kind = 'জমা';
    showDialog(
        context: context,
        builder: (d) => StatefulBuilder(
              builder: (d, sd) => AlertDialog(
                title: const Text('ক্যাশ / ব্যাংক লেনদেন'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField(
                    value: kind,
                    items: ['জমা', 'উত্তোলন']
                        .map((x) =>
                            DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (x) => sd(() => kind = x!),
                  ),
                  DropdownButtonFormField(
                    value: acc,
                    items: [
                      ...accountNames,
                      ...banks.where((b) => !accountNames.contains(b))
                    ]
                        .map((x) =>
                            DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (x) => sd(() => acc = x!),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'টাকার পরিমাণ'),
                  ),
                  TextField(
                    controller: note,
                    decoration:
                        const InputDecoration(labelText: 'বিবরণ / অফিস খরচ'),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('বাতিল')),
                  ElevatedButton(
                      onPressed: () async {
                        final a = double.tryParse(amount.text) ?? 0;
                        if (a <= 0) return;
                        await movement(
                            acc,
                            a,
                            note.text.isEmpty
                                ? (kind == 'জমা'
                                    ? 'টাকা জমা'
                                    : 'টাকা উত্তোলন')
                                : note.text,
                            kind == 'জমা');
                        if (d.mounted) Navigator.pop(d);
                      },
                      child: const Text('সেভ'))
                ],
              ),
            ));
  }
}class InvoiceForm extends StatefulWidget {
  final int no;
  final List<String> accounts;
  final Future<void> Function(
      String, String, String, List<Map<String, dynamic>>, double, String)
      onSave;

  const InvoiceForm({
    super.key,
    required this.no,
    required this.accounts,
    required this.onSave,
  });

  @override
  State<InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<InvoiceForm> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final addr = TextEditingController();
  final paid = TextEditingController(text: '0');

  final items = <Map<String, dynamic>>[];
  String account = 'Cash';

  double get total =>
      items.fold(0, (s, e) => s + val(e['qty']) * val(e['rate']));

  Widget field(String label, TextEditingController c) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  void addItem() {
    final n = TextEditingController();
    final q = TextEditingController();
    final r = TextEditingController();

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('পণ্য যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(
                  labelText: 'পণ্যের বিবরণ'),
            ),
            TextField(
              controller: q,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'পরিমাণ'),
            ),
            TextField(
              controller: r,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'দর'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(q.text) ?? 0;
              final rate = double.tryParse(r.text) ?? 0;

              if (n.text.isEmpty || qty <= 0 || rate < 0) return;

              setState(() => items.add({
                    'name': n.text,
                    'qty': qty,
                    'rate': rate
                  }));

              Navigator.pop(d);
            },
            child: const Text('যোগ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.blueGrey, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.indigo,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'ক্যাশ / ক্রেডিট মেমো',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  company,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.brown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(address, textAlign: TextAlign.center),
                const Divider(thickness: 2),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ক্রমিক নং: ${widget.no}'),
                    Text('তারিখ: $dateNow'),
                  ],
                ),
              ],
            ),
          ),

          field('ক্রেতার নাম', name),
          field('ঠিকানা', addr),
          field('মোবাইল নম্বর', phone),

          const Text(
            'পণ্যের বিবরণ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          ...items.asMap().entries.map(
            (e) => Card(
              child: ListTile(
                title: Text('${e.value['name']}'),
                subtitle: Text(
                  '${e.value['qty']} × ${e.value['rate']} = ${tk(val(e.value['qty']) * val(e.value['rate']))}',
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onPressed: () =>
                      setState(() => items.removeAt(e.key)),
                ),
              ),
            ),
          ),

          OutlinedButton.icon(
            onPressed: addItem,
            icon: const Icon(Icons.add),
            label: const Text('পণ্য যোগ করুন'),
          ),

          Text(
            'মোট টাকা: ${tk(total)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          field('আজকের জমা টাকা', paid),

          DropdownButtonFormField(
            value: account,
            decoration:
                const InputDecoration(labelText: 'জমার মাধ্যম'),
            items: widget.accounts
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(x),
                    ))
                .toList(),
            onChanged: (x) => setState(() => account = x!),
          ),

          Text(
            'বাকি: ${tk(total - (double.tryParse(paid.text) ?? 0))} টাকা',
          ),

          ElevatedButton.icon(
            onPressed: () async {
              final v = double.tryParse(paid.text) ?? 0;

              if (name.text.trim().isEmpty ||
                  items.isEmpty ||
                  v < 0 ||
                  v > total) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('তথ্য সঠিকভাবে পূরণ করুন'),
                  ),
                );
                return;
              }

              await widget.onSave(
                name.text,
                phone.text,
                addr.text,
                List.from(items),
                v,
                account,
              );

              name.clear();
              phone.clear();
              addr.clear();
              paid.text = '0';

              setState(() => items.clear());

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ইনভয়েস সেভ হয়েছে'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('ইনভয়েস সেভ করুন'),
          ),
        ],
      );
}

class PartyPage extends StatefulWidget {
  final Map<String, dynamic> p;
  final List<String> accounts;

  final Future<void> Function(double, String, String) onReceive;
  final Future<void> Function(double, String) onPurchase;
  final Future<void> Function(double, String, String) onPay;

  const PartyPage({
    super.key,
    required this.p,
    required this.accounts,
    required this.onReceive,
    required this.onPurchase,
    required this.onPay,
  });

  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  Future<void> dialog(String mode) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    String acc = 'Cash';

    final title = mode == 'in'
        ? 'টাকা গ্রহণ'
        : mode == 'buy'
            ? 'পণ্য ক্রয়'
            : 'টাকা পেমেন্ট';

    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, sd) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'টাকার পরিমাণ'),
              ),
              if (mode != 'buy')
                DropdownButtonFormField(
                  value: acc,
                  items: widget.accounts
                      .map((x) => DropdownMenuItem(
                            value: x,
                            child: Text(x),
                          ))
                      .toList(),
                  onChanged: (x) => sd(() => acc = x!),
                ),
              TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'বিবরণ'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () async {
                final a = double.tryParse(amount.text) ?? 0;
                if (a <= 0) return;

                if (mode == 'in') {
                  await widget.onReceive(a, acc, note.text);
                }
                if (mode == 'buy') {
                  await widget.onPurchase(a, note.text);
                }
                if (mode == 'out') {
                  await widget.onPay(a, acc, note.text);
                }

                if (d.mounted) Navigator.pop(d);
                if (mounted) setState(() {});
              },
              child: const Text('সেভ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = (widget.p['rows'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final rec = rows
        .where((r) =>
            (r['side'] ?? 'receivable') == 'receivable')
        .fold<double>(
            0, (s, r) => s + val(r['debit']) - val(r['credit']));

    final pay = rows
        .where((r) => r['side'] == 'payable')
        .fold<double>(
            0, (s, r) => s + val(r['credit']) - val(r['debit']));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.p['name']}'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo.shade100,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '${widget.p['name']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                    '${widget.p['address'] ?? ''} ${widget.p['phone'] ?? ''}'),
                Text(
                  'আমাদের পাওনা: ${tk(rec)} টাকা',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'আমাদের দেনা: ${tk(pay)} টাকা',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Wrap(
            spacing: 4,
            children: [
              ElevatedButton(
                onPressed: () => dialog('in'),
                child: const Text('টাকা গ্রহণ'),
              ),
              ElevatedButton(
                onPressed: () => dialog('buy'),
                child: const Text('পণ্য ক্রয়'),
              ),
              ElevatedButton(
                onPressed: () => dialog('out'),
                child: const Text('টাকা পেমেন্ট'),
              ),
            ],
          ),

          const Text(
            'খতিয়ান',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('তারিখ')),
                    DataColumn(label: Text('বিবরণ')),
                    DataColumn(label: Text('জমা')),
                    DataColumn(label: Text('খরচ')),
                    DataColumn(label: Text('ধরন')),
                  ],
                  rows: rows.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${r['date']}')),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text('${r['details']}'),
                          ),
                        ),
                        DataCell(Text(tk(val(r['credit'])))),
                        DataCell(Text(tk(val(r['debit'])))),
                        DataCell(Text(
                          r['side'] == 'payable' ? 'দেনা' : 'পাওনা',
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> rows;
  final double balance;

  const AccountPage({
    super.key,
    required this.name,
    required this.rows,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    double b = 0;

    return Scaffold(
      appBar: AppBar(title: Text('$name খতিয়ান')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'অবশিষ্ট ব্যালেন্স: ${tk(balance)} টাকা',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: rows.map((r) {
                b += val(r['amount']);

                return ListTile(
                  title: Text('${r['details']}'),
                  subtitle: Text('${r['date']}'),
                  trailing: Text(
                    '${val(r['amount']) >= 0 ? 'জমা' : 'উত্তোলন'} ${tk(val(r['amount']).abs())}\nব্যালেন্স ${tk(b)}',
                    textAlign: TextAlign.end,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
