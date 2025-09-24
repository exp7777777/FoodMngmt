import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers.dart';
import 'localization.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).shoppingListTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).itemName,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _amount,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).quantityUnit,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty) return;
                    await context.read<ShoppingProvider>().add(
                      _name.text.trim(),
                      amount:
                          _amount.text.trim().isEmpty
                              ? null
                              : _amount.text.trim(),
                    );
                    _name.clear();
                    _amount.clear();
                  },
                  child: Text(AppLocalizations.of(context).add),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ShoppingProvider>(
              builder: (context, sp, _) {
                final items = sp.items;
                if (items.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context).noItems),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: CheckboxListTile(
                        value: it.checked,
                        title: Text(it.name),
                        subtitle: it.amount == null ? null : Text(it.amount!),
                        onChanged:
                            (v) => context.read<ShoppingProvider>().toggle(
                              it.id!,
                              v ?? false,
                            ),
                        secondary: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            icon: Icon(Icons.delete_outline),
                            onPressed:
                                () => context.read<ShoppingProvider>().remove(
                                  it.id!,
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<ShoppingProvider>().clearChecked(),
        icon: Icon(Icons.cleaning_services_outlined),
        label: Text(AppLocalizations.of(context).clearChecked),
      ),
    );
  }
}
