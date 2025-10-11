import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'providers.dart';
import 'localization.dart';
import 'location_service.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  Position? _currentPosition;
  String? _locationError;
  Map<String, List<Map<String, dynamic>>> _storeRecommendations = {};

  @override
  void initState() {
    super.initState();
    _loadLocationAndRecommendations();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndRecommendations() async {
    setState(() {
      _locationError = null;
    });

    // 獲取當前位置
    final position = await LocationService.instance.getCurrentLocation();

    if (position == null) {
      setState(() {
        _locationError = AppLocalizations.of(context).locationPermissionDenied;
      });
      return;
    }

    setState(() {
      _currentPosition = position;
    });

    // 為每個購物項目生成商店推薦
    await _generateStoreRecommendations();
  }

  Future<void> _generateStoreRecommendations() async {
    final shoppingProvider = context.read<ShoppingProvider>();
    final locationService = LocationService.instance;

    for (final item in shoppingProvider.items) {
      if (!item.checked) {
        // 只為未完成的項目生成推薦
        final stores = await locationService.getNearbyStores(item.name);
        _storeRecommendations[item.name] = stores;
      }
    }

    setState(() {});
  }

  Widget _buildLocationReminderCard() {
    if (_locationError != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.location_off, color: Colors.orange),
              const SizedBox(height: 8),
              Text(
                _locationError!,
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadLocationAndRecommendations,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).getLocation),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.location_searching),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).getLocation),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadLocationAndRecommendations,
                icon: const Icon(Icons.my_location),
                label: Text(AppLocalizations.of(context).getLocation),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStoreRecommendations(String itemName) {
    final stores = _storeRecommendations[itemName] ?? [];
    if (stores.isEmpty) return const SizedBox.shrink();

    // 找出推薦的商店
    final recommendedStores =
        stores.where((store) => store['recommended'] == true).toList();
    final otherStores =
        stores.where((store) => store['recommended'] != true).toList();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).nearbyStores,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 顯示推薦的商店
          if (recommendedStores.isNotEmpty) ...[
            Text(
              '推薦商店：',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            ...recommendedStores
                .take(1)
                .map(
                  (store) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${store['name']} (${store['distance']})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            store['type'],
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 6),
          ],

          // 顯示其他商店
          if (otherStores.isNotEmpty) ...[
            Text(
              '其他商店：',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            ...otherStores
                .take(2)
                .map(
                  (store) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${store['name']} (${store['distance']})',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Text(
                          store['type'],
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          if (stores.length > 3)
            Text(
              '...還有 ${stores.length - 3} 個商店',
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).shoppingListTitle),
      ),
      body: Column(
        children: [
          // 新增項目輸入區域
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
                    // 新增項目後重新生成推薦
                    await _generateStoreRecommendations();
                  },
                  child: Text(AppLocalizations.of(context).add),
                ),
              ],
            ),
          ),

          // 位置提醒卡片
          _buildLocationReminderCard(),

          // 購物清單區域標題
          if (_currentPosition != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).shoppingListTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 購物清單項目
          Expanded(
            child: Consumer<ShoppingProvider>(
              builder: (context, sp, _) {
                final items = sp.items;
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).noItems,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_currentPosition != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context).tapToViewStores,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return Column(
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: CheckboxListTile(
                            value: it.checked,
                            title: Text(
                              it.name,
                              style: TextStyle(
                                decoration:
                                    it.checked
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                color: it.checked ? Colors.grey : null,
                              ),
                            ),
                            subtitle:
                                it.amount == null
                                    ? null
                                    : Text(
                                      it.amount!,
                                      style: TextStyle(
                                        decoration:
                                            it.checked
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                        color: it.checked ? Colors.grey : null,
                                      ),
                                    ),
                            onChanged: (v) async {
                              await context.read<ShoppingProvider>().toggle(
                                it.id!,
                                v ?? false,
                              );
                              // 更新推薦（已完成的項目不需要推薦）
                              if (v == true) {
                                _storeRecommendations.remove(it.name);
                                setState(() {});
                              }
                            },
                            secondary: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: IconButton(
                                icon: Icon(Icons.delete_outline),
                                onPressed:
                                    () => context
                                        .read<ShoppingProvider>()
                                        .remove(it.id!),
                              ),
                            ),
                          ),
                        ),
                        // 商店推薦區域（只為未完成的項目顯示）
                        if (!it.checked) _buildStoreRecommendations(it.name),
                      ],
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
