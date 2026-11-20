import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const InvoiceApp());
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Invoice & Ledger',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Customer {
  String name;
  String phone;
  String address;
  List<Map<String, dynamic>> ledger;

  Customer({
    required this.name,
    required this.phone,
    required this.address,
    List<Map<String, dynamic>>? ledger,
  }) : ledger = ledger ?? [];

  double get balance {
    double total = 0;
    for (var entry in ledger) {
      total += (entry['debit'] as num).toDouble();
      total -= (entry['credit'] as num).toDouble();
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'ledger': ledger,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      ledger: List<Map<String, dynamic>>.from(
        (json['ledger'] ?? []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Customer> customers = [];
  int invoiceNumber = 1;
  int page = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('customers');
    if (saved != null) {
      final data = jsonDecode(saved) as List;
      customers = data.map(
        (e) => Customer.fromJson(e),
      ).toList();
    }
    invoiceNumber = prefs.getInt('invoiceNumber') ?? 1;
    if (mounted) setState(() {});
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customers',
      jsonEncode(customers.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt('invoiceNumber', invoiceNumber);
  }

  Customer? findCustomer(String name) {
    for (var c in customers) {
      if (c.name.trim().toLowerCase() ==
          name.trim().toLowerCase()) {
        return c;
      }
    }
    return null;
  }

  void addInvoice(
    String name,
    String phone,
    String address,
    List<Map<String, dynamic>> items,
    double paid,
  ) async {
    if (name.trim().isEmpty || items.isEmpty) return;

    Customer? customer = findCustomer(name);

    if (customer == null) {
      customer = Customer(
        name: name.trim(),
        phone: phone,
        address: address,
      );
      customers.add(customer);
    } else {
      customer.phone = phone;
      customer.address = address;
    }

    double total = 0;
    List<String> particulars = [];

    for (var item in items) {
      double amount =
          (item['qty'] as num).toDouble() *
          (item['rate'] as num).toDouble();

      total += amount;

      particulars.add(
        '${item['name']}-${item['qty']}×${item['rate']}',
      );
    }

    String date = DateTime.now().toString().substring(0, 10);

    customer.ledger.add({
      'date': date,
      'particulars': particulars.join('\n'),
      'lf': invoiceNumber.toString(),
      'debit': total,
      'credit': 0.0,
    });

    if (paid > 0) {
      customer.ledger.add({
        'date': date,
        'particulars': 'Cash Payment',
        'lf': 'Cash',
        'debit': 0.0,
        'credit': paid,
      });
    }

    invoiceNumber++;
    await saveData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ইনভয়েস সফলভাবে সেভ হয়েছে')),
    );

    setState(() {});
  }

  void addPayment(Customer customer, double amount) async {
    if (amount <= 0) return;

    customer.ledger.add({
      'date': DateTime.now().toString().substring(0, 10),
      'particulars': 'Cash Payment',
      'lf': 'Cash',
      'debit': 0.0,
      'credit': amount,
    });

    await saveData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      dashboard(),
      InvoicePage(
        invoiceNumber: invoiceNumber,
        onSave: addInvoice,
      ),
      customerPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice & Customer Ledger'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: screens[page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) {
          setState(() => page = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'ইনভয়েস',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'কাস্টমার',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    double totalBalance = customers.fold(
      0,
      (sum, c) => sum + c.balance,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          card('মোট কাস্টমার', '${customers.length}',
              Icons.people, Colors.blue),
          card('মোট বকেয়া', totalBalance.toStringAsFixed(2),
              Icons.account_balance_wallet, Colors.green),
          card('পরবর্তী ইনভয়েস', '$invoiceNumber',
              Icons.receipt, Colors.orange),
          const SizedBox(height: 25),
          const Text(
            'Invoice & Automatic Ledger System',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget card(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 35),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget customerPage() {
    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final c = customers[index];

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(c.name),
            subtitle: Text(
              '${c.phone}\nবকেয়া: ${c.balance.toStringAsFixed(2)} টাকা',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LedgerPage(
                    customer: c,
                    onPayment: (amount) => addPayment(c, amount),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// INVOICE PAGE

class InvoicePage extends StatefulWidget {
  final int invoiceNumber;
  final Function(
    String,
    String,
    String,
    List<Map<String, dynamic>>,
    double,
  ) onSave;

  const InvoicePage({
    super.key,
    required this.invoiceNumber,
    required this.onSave,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final paid = TextEditingController(text: '0');

  final List<Map<String, dynamic>> items = [];

  double get total {
    return items.fold(0, (sum, item) {
      return sum +
          (item['qty'] as num) * (item['rate'] as num);
    });
  }

  void addItem() {
    final product = TextEditingController();
    final qty = TextEditingController();
    final rate = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন পণ্য যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: product,
              decoration: const InputDecoration(
                labelText: 'পণ্যের নাম',
              ),
            ),
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'পরিমাণ (কেজি/পিস)',
              ),
            ),
            TextField(
              controller: rate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'দর',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              if (product.text.isEmpty ||
                  (double.tryParse(qty.text) ?? 0) <= 0 ||
                  (double.tryParse(rate.text) ?? 0) < 0) {
                return;
              }

              setState(() {
                items.add({
                  'name': product.text,
                  'qty': double.parse(qty.text),
                  'rate': double.parse(rate.text),
                });
              });

              Navigator.pop(context);
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }

  Widget field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Text(
          'ক্যাশ / ক্রেডিট মেমো',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
        const Divider(thickness: 2),

        Text('ইনভয়েস নং: ${widget.invoiceNumber}'),

        Text('তারিখ: ${DateTime.now().toString().substring(0, 10)}'),

        const SizedBox(height: 12),

        field('কাস্টমারের নাম', name),
        field('মোবাইল নম্বর', phone),
        field('ঠিকানা', address),

        const SizedBox(height: 15),

        const Text(
          'পণ্যের বিবরণ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),

        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final amount = item['qty'] * item['rate'];

          return Card(
            child: ListTile(
              title: Text(item['name']),
              subtitle: Text(
                '${item['qty']} × ${item['rate']} = ${amount.toStringAsFixed(2)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => items.removeAt(i));
                },
              ),
            ),
          );
        }),

        OutlinedButton.icon(
          onPressed: addItem,
          icon: const Icon(Icons.add),
          label: const Text('নতুন পণ্য যোগ করুন'),
        ),

        const SizedBox(height: 15),

        Text(
          'মোট টাকা: ${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        field('আজকের জমা টাকা', paid),

        Text(
          'বর্তমান ইনভয়েসের বাকি: '
          '${(total - (double.tryParse(paid.text) ?? 0)).toStringAsFixed(2)} টাকা',
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () {
            final payment = double.tryParse(paid.text) ?? 0;

            if (name.text.trim().isEmpty || items.isEmpty ||
                payment < 0 || payment > total) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('তথ্য সঠিকভাবে পূরণ করুন'),
                ),
              );
              return;
            }

            widget.onSave(
              name.text,
              phone.text,
              address.text,
              List.from(items),
              payment,
            );

            name.clear();
            phone.clear();
            address.clear();
            paid.text = '0';
            setState(() => items.clear());
          },
          icon: const Icon(Icons.save),
          label: const Text('ইনভয়েস সেভ করুন'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

// CUSTOMER LEDGER PAGE

class LedgerPage extends StatefulWidget {
  final Customer customer;
  final Function(double) onPayment;

  const LedgerPage({
    super.key,
    required this.customer,
    required this.onPayment,
  });

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  void paymentDialog() {
    final amount = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('কাস্টমারের জমা টাকা'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'টাকার পরিমাণ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(amount.text) ?? 0;

              if (value <= 0) return;

              widget.onPayment(value);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('জমা করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: paymentDialog,
        icon: const Icon(Icons.add),
        label: const Text('জমা টাকা'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: Colors.indigo.shade100,
            child: Column(
              children: [
                Text(customer.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )),
                Text(customer.address),
                Text(customer.phone),
                const SizedBox(height: 8),
                Text(
                  'অবশিষ্ট: ${customer.balance.toStringAsFixed(2)} টাকা',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'CUSTOMER LEDGER',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(Colors.indigo.shade200),
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Particulars')),
                    DataColumn(label: Text('L.F.')),
                    DataColumn(label: Text('Credit')),
                    DataColumn(label: Text('Debit')),
                    DataColumn(label: Text('Balance')),
                  ],
                  rows: _ledgerRows(customer),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _ledgerRows(Customer customer) {
    double balance = 0;

    return customer.ledger.map((entry) {
      final debit = (entry['debit'] as num).toDouble();
      final credit = (entry['credit'] as num).toDouble();

      balance += debit - credit;

      return DataRow(
        cells: [
          DataCell(Text(entry['date'].toString())),
          DataCell(
            SizedBox(
              width: 150,
              child: Text(entry['particulars'].toString()),
            ),
          ),
          DataCell(Text(entry['lf'].toString())),
          DataCell(Text(credit.toStringAsFixed(2))),
          DataCell(Text(debit.toStringAsFixed(2))),
          DataCell(
            Text(
              balance.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }).toList();
  }
}
