
class InvoiceForm extends StatefulWidget {
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
