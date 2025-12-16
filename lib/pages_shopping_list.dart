import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _showNearbyStores = true; // 控制是否顯示附近店家
  Map<String, bool> _loadingStores = {}; // 追蹤每個項目的載入狀態

  @override
  void initState() {
    super.initState();
    // 只有在啟用顯示附近店家時才載入推薦資料
    if (_showNearbyStores) {
      _loadLocationAndRecommendations();
    }
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

  Future<void> _generateStoreRecommendations({String? itemName}) async {
    final shoppingProvider = context.read<ShoppingProvider>();
    final locationService = LocationService.instance;

    if (itemName != null) {
      // 為單個項目生成推薦
      if (_loadingStores[itemName] == true) return; // 避免重複載入

      setState(() {
        _loadingStores[itemName] = true;
      });

      try {
        final stores = await locationService.getNearbyStores(itemName);
        setState(() {
          _storeRecommendations[itemName] = stores;
        });
      } catch (e) {
        debugPrint('載入商店推薦失敗: $e');
        setState(() {
          _loadingStores[itemName] = false;
        });
      }
    } else {
      // 為所有未完成的項目生成推薦（舊邏輯）
      for (final item in shoppingProvider.items) {
        if (!item.checked) {
          final stores = await locationService.getNearbyStores(item.name);
          _storeRecommendations[item.name] = stores;
        }
      }
      setState(() {});
    }
  }

  Future<void> _openStoreInMap(Map<String, dynamic> store) async {
    try {
      String url;

      // 如果有 placeId，使用 place_id 查詢（更精確）
      if (store['placeId'] != null && store['placeId'].toString().isNotEmpty) {
        url =
            'https://www.google.com/maps/search/?api=1&query=Google&query_place_id=${store['placeId']}';
      } else {
        // 否則使用店家名稱和地址搜尋
        final query = Uri.encodeComponent(
          '${store['name']} ${store['address']}',
        );
        url = 'https://www.google.com/maps/search/?api=1&query=$query';
      }

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無法打開 Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('打開 Google Maps 失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打開 Google Maps 失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _showAllStores(String itemName, List<Map<String, dynamic>> stores) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.store, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '「$itemName」附近店家',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: stores.length,
                itemBuilder: (context, index) {
                  final store = stores[index];
                  final isRecommended = store['recommended'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isRecommended ? Colors.green[50] : Colors.white,
                    child: ListTile(
                      leading: Icon(
                        isRecommended ? Icons.star : Icons.store,
                        color: isRecommended ? Colors.green : Colors.blue,
                      ),
                      title: Text(
                        store['name'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isRecommended
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${store['type']} • ${store['distance']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (store['address'] != null)
                            Text(
                              store['address'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (store['rating'] != null &&
                              store['rating'].toString().isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  store['rating'].toString(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.map, color: Colors.blue[700]),
                        onPressed: () {
                          Navigator.pop(context);
                          _openStoreInMap(store);
                        },
                        tooltip: '在地圖中查看',
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          ),
    );
  }

  Widget _buildStoreRecommendations(String itemName) {
    // 如果沒有啟用顯示附近店家，直接返回
    if (!_showNearbyStores) {
      return const SizedBox.shrink();
    }

    final stores = _storeRecommendations[itemName] ?? [];

    // 如果沒有商店資料且沒有在載入中，觸發載入
    if (stores.isEmpty && _loadingStores[itemName] != true) {
      // 異步觸發載入，避免阻塞UI
      Future.microtask(() => _generateStoreRecommendations(itemName: itemName));
      _loadingStores[itemName] = true;
    }

    // 如果正在載入且沒有商店資料，顯示載入動畫
    if (_loadingStores[itemName] == true && stores.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '正在尋找附近商店...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (stores.isEmpty) return const SizedBox.shrink();

    // 找出推薦的商店
    final recommendedStores =
        stores.where((store) => store['recommended'] == true).toList();

    return InkWell(
      onTap: () => _showAllStores(itemName, stores),
      child: Container(
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
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).nearbyStores,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Text(
                  '找到 ${stores.length} 個店家',
                  style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.blue[700],
                ),
              ],
            ),
            if (recommendedStores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '推薦：${recommendedStores.first['name']} (${recommendedStores.first['distance']})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).shoppingListTitle),
        actions: [
          IconButton(
            icon: Icon(
              _showNearbyStores ? Icons.location_on : Icons.location_off,
            ),
            tooltip: _showNearbyStores ? '隱藏附近店家' : '顯示附近店家',
            onPressed: () {
              setState(() {
                _showNearbyStores = !_showNearbyStores;
                // 如果切換為顯示狀態，需要重新生成推薦
                if (_showNearbyStores) {
                  _loadLocationAndRecommendations();
                } else {
                  // 如果切換為隱藏狀態，清空推薦資料
                  _storeRecommendations.clear();
                  _loadingStores.clear();
                }
              });
            },
          ),
        ],
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

                    // 檢查用戶是否登入
                    final authProvider = context.read<AuthProvider>();
                    if (!authProvider.isLoggedIn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('請先登入才能新增購物項目'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    // 防止重複點擊
                    final shoppingProvider = context.read<ShoppingProvider>();
                    if (shoppingProvider.isLoading) return;

                    try {
                      await shoppingProvider.add(
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
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('新增失敗: $e'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context).add),
                ),
              ],
            ),
          ),

          // 位置提醒卡片
          _buildLocationReminderCard(),

          // 購物清單項目
          Expanded(
            child: Consumer<ShoppingProvider>(
              builder: (context, sp, _) {
                final items = sp.items;

                if (sp.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (sp.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          sp.errorMessage!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => sp.refresh(),
                          child: Text('重試'),
                        ),
                      ],
                    ),
                  );
                }
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
                                it.id ?? '',
                                v ?? false,
                              );
                              // 更新推薦狀態
                              if (v == true) {
                                // 項目被勾選，移除商店推薦
                                _storeRecommendations.remove(it.name);
                                _loadingStores.remove(it.name);
                              } else {
                                // 項目被取消勾選，需要重新生成商店推薦
                                if (_showNearbyStores) {
                                  // 重置載入狀態並重新生成推薦
                                  _loadingStores.remove(it.name);
                                  _storeRecommendations.remove(it.name);
                                  _generateStoreRecommendations(
                                    itemName: it.name,
                                  );
                                }
                              }
                              setState(() {});
                            },
                            secondary: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: IconButton(
                                icon: Icon(Icons.delete_outline),
                                onPressed: () async {
                                  // 清理該項目的商店推薦資料
                                  _storeRecommendations.remove(it.name);
                                  _loadingStores.remove(it.name);

                                  // 刪除項目
                                  await context.read<ShoppingProvider>().remove(
                                    it.id ?? '',
                                  );

                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                        // 商店推薦區域（只為未完成的項目顯示，並且啟用了附近店家功能）
                        if (!it.checked && _showNearbyStores) ...[
                          _buildStoreRecommendations(it.name),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
