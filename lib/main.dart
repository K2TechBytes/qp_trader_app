import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;

const String BASE_URL = 'https://kk-infotech.com';
const int HTTP_TIMEOUT = 15;

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  
  factory SessionManager() => _instance;
  SessionManager._internal();
  
  String? _username;
  String? _sessionCookie;
  DateTime? _cookieExpiry;
  
  String? get username => _username;
  bool get isLoggedIn => _username != null && !_isCookieExpired();
  
  void setUsername(String username) => _username = username;
  
  void setSessionCookie(String setCookieHeader) {
    try {
      final parts = setCookieHeader.split(';');
      if (parts.isNotEmpty) {
        _sessionCookie = parts[0].trim();
        _cookieExpiry = DateTime.now().add(const Duration(hours: 24));
      }
    } catch (e) {
      print('Error parsing cookie: $e');
    }
  }
  
  bool _isCookieExpired() {
    if (_cookieExpiry == null) return true;
    return DateTime.now().isAfter(_cookieExpiry!);
  }
  
  String getCookieHeader() {
    if (_isCookieExpired()) {
      logout();
      return '';
    }
    return _sessionCookie ?? '';
  }
  
  void logout() {
    _username = null;
    _sessionCookie = null;
    _cookieExpiry = null;
  }
}

void main() {
  runApp(const TradingApp());
}

class TradingApp extends StatelessWidget {
  const TradingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Prop',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A82E4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1117),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isLoggedIn = false;
  String _username = '';

  void _handleLogin(String username) {
    setState(() {
      _isLoggedIn = true;
      _username = username;
    });
  }

  void _handleLogout() {
    final session = SessionManager();
    session.logout();
    setState(() {
      _isLoggedIn = false;
      _username = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn
        ? MainTradingScreen(username: _username, onLogout: _handleLogout)
        : LoginPage(onLoginSuccess: _handleLogin);
  }
}

class LoginPage extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const LoginPage({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        _showError('Please enter username and password');
        return;
      }

      final response = await http.post(
        Uri.parse('$BASE_URL/login'),
        body: {'username': username, 'password': password},
      ).timeout(
        const Duration(seconds: HTTP_TIMEOUT),
        onTimeout: () => throw TimeoutException('Login request timed out'),
      );

      if (!mounted) return;

      final session = SessionManager();
      
      if (response.statusCode == 401) {
        _showError('Invalid username or password');
      } else if (response.statusCode == 200 || response.statusCode == 301 || response.statusCode == 302) {
        if (response.headers.containsKey('set-cookie')) {
          session.setSessionCookie(response.headers['set-cookie']!);
        }
        session.setUsername(username);
        widget.onLoginSuccess(username);
      } else if (response.statusCode >= 500) {
        _showError('Server error (${response.statusCode}). Please try again later.');
      } else {
        _showError('Login failed. Please try again.');
      }
    } on TimeoutException {
      _showError('Connection timed out. Check your internet connection.');
    } on SocketException {
      _showError('No internet connection. Please check your network.');
    } catch (e) {
      _showError('Error: ${e.toString().substring(0, 50)}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, color: Color(0xFF2A82E4), size: 50),
              const SizedBox(height: 24),
              const Text(
                'Quick Prop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trade Smart, Invest Wise',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Username',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF1C1F26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF2A82E4)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF1C1F26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF2A82E4)),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A82E4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainTradingScreen extends StatefulWidget {
  final String username;
  final VoidCallback onLogout;

  const MainTradingScreen({
    Key? key,
    required this.username,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  int _selectedNavIndex = 0;
  String? _selectedStock;
  String _selectedAction = 'BUY';
  final _quantityController = TextEditingController();
  double _totalFunds = 0;
  List<String> _stockSymbols = [];
  Map<String, double> _stockPrices = {};
  Map<String, double> _previousPrices = {};
  
  Map<String, dynamic>? _cachedPositions;
  List<dynamic>? _cachedOrders;
  Map<String, dynamic>? _cachedOptions;
  
  Map<String, double> _optionPrices = {};
  Map<String, double> _previousOptionPrices = {};
  
  Timer? _priceUpdateTimer;
  Timer? _balanceUpdateTimer;
  Timer? _positionsUpdateTimer;
  Timer? _ordersUpdateTimer;
  Timer? _optionsUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startPriceUpdates();
    _startBackgroundUpdates();
  }

  void _startPriceUpdates() {
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateStockPrices();
    });
  }

  void _startBackgroundUpdates() {
    _balanceUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateBalanceBackground();
    });

    _positionsUpdateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _updatePositionsBackground();
    });
    
    _ordersUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateOrdersBackground();
    });
    
    _optionsUpdateTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _updateOptionsBackground();
    });
  }

  Future<void> _updateBalanceBackground() async {
    try {
      final balance = await _fetchBalance();
      if (mounted) {
        setState(() {
          _totalFunds = balance;
        });
      }
    } catch (e) {
      print('Background error updating balance: $e');
    }
  }

  Future<void> _updatePositionsBackground() async {
    try {
      final data = await _fetchPositions();
      if (mounted) {
        setState(() {
          _cachedPositions = data;
        });
      }
    } catch (e) {
      print('Background error updating positions: $e');
    }
  }

  Future<void> _updateOrdersBackground() async {
    try {
      final orders = await _fetchOrders();
      if (mounted) {
        setState(() {
          _cachedOrders = orders;
        });
      }
    } catch (e) {
      print('Background error updating orders: $e');
    }
  }

  Future<void> _updateOptionsBackground() async {
    try {
      final options = await _fetchOptions();
      if (mounted) {
        final optionsList = List<dynamic>.from(options['options'] ?? []);
        for (final option in optionsList) {
          final symbol = option['symbol'];
          final ltp = double.tryParse(option['ltp'].toString()) ?? 0.0;
          
          _previousOptionPrices[symbol] = _optionPrices[symbol] ?? ltp;
          _optionPrices[symbol] = ltp;
        }
        
        setState(() {
          _cachedOptions = options;
        });
      }
    } catch (e) {
      print('Background error updating options: $e');
    }
  }

  Future<void> _updateStockPrices() async {
    try {
      final session = SessionManager();
      if (!session.isLoggedIn) {
        return;
      }
      
      final cookie = session.getCookieHeader();

      for (String symbol in _stockSymbols) {
        try {
          final response = await http.get(
            Uri.parse('$BASE_URL/get_stock_ltp?symbol=$symbol'),
            headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            try {
              final data = jsonDecode(response.body);
              final ltp = double.tryParse(data['ltp'].toString()) ?? 0.0;
              if (mounted) {
                setState(() {
                  _previousPrices[symbol] = _stockPrices[symbol] ?? ltp;
                  _stockPrices[symbol] = ltp;
                });
              }
            } catch (e) {
              print('Parse error for $symbol: $e');
            }
          }
        } catch (e) {
          print('Error updating price for $symbol: $e');
        }
      }
    } catch (e) {
      print('Error updating prices: $e');
    }
  }

  Future<void> _loadAllData() async {
    try {
      await _loadFundDetails();
      await _loadStockSymbols();
      await _updateStockPrices();
      
      _cachedPositions = await _fetchPositions();
      _cachedOrders = await _fetchOrders();
      _cachedOptions = await _fetchOptions();
      
      final optionsList = List<dynamic>.from(_cachedOptions?['options'] ?? []);
      for (final option in optionsList) {
        final symbol = option['symbol'];
        final ltp = double.tryParse(option['ltp'].toString()) ?? 0.0;
        _optionPrices[symbol] = ltp;
        _previousOptionPrices[symbol] = ltp;
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<double> _fetchBalance() async {
    try {
      final session = SessionManager();
      if (!session.isLoggedIn) {
        return 0.0;
      }
      
      final cookie = session.getCookieHeader();
      final response = await http.get(
        Uri.parse('$BASE_URL/get_balance'),
        headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
      ).timeout(const Duration(seconds: HTTP_TIMEOUT));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final liveBalance = double.tryParse(data['live_balance'].toString()) ?? 0.0;
          print('Balance fetched: ₹$liveBalance');
          return liveBalance;
        } catch (e) {
          print('Parse error for balance: $e');
          return _totalFunds;
        }
      }
      return _totalFunds;
    } on TimeoutException {
      print('Timeout fetching balance');
      return _totalFunds;
    } on SocketException {
      print('No internet fetching balance');
      return _totalFunds;
    } catch (e) {
      print('Error fetching balance: $e');
      return _totalFunds;
    }
  }

  Future<void> _loadFundDetails() async {
    try {
      final balance = await _fetchBalance();
      if (mounted) {
        setState(() => _totalFunds = balance);
      }
    } catch (e) {
      print('Error loading funds: $e');
    }
  }

  Future<void> _loadStockSymbols() async {
    try {
      final symbols = ['INFY', 'TCS', 'WIPRO', 'SUNPHARMA'];
      if (mounted) {
        setState(() {
          _stockSymbols = symbols;
          _selectedStock = symbols.isNotEmpty ? symbols[0] : null;
          for (String symbol in symbols) {
            _stockPrices[symbol] = 0.0;
            _previousPrices[symbol] = 0.0;
          }
        });
      }
    } catch (e) {
      print('Error loading symbols: $e');
    }
  }

  void _showConfirmationDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1C1F26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A82E4),
                      ),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    if (_selectedStock == null || _selectedStock!.isEmpty || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    final qty = _quantityController.text;
    final currentPrice = _stockPrices[_selectedStock] ?? 0.0;
    final totalValue = (int.tryParse(qty) ?? 0) * currentPrice;

    _showConfirmationDialog(
      'Confirm ${_selectedAction} Order',
      'Stock: $_selectedStock\nQuantity: $qty\nPrice: ₹${currentPrice.toStringAsFixed(2)}\nTotal: ₹${totalValue.toStringAsFixed(2)}',
      () => _executeOrder(),
    );
  }

  Future<void> _executeOrder() async {
    try {
      final session = SessionManager();
      if (!session.isLoggedIn) {
        return;
      }
      
      final cookie = session.getCookieHeader();
      final endpoint = _selectedAction == 'BUY' ? 'place_buy_order' : 'place_sell_order';
      final fieldName = _selectedAction == 'BUY' ? 'stockSymbolBuy' : 'stockSymbolSell';

      final response = await http.post(
        Uri.parse('$BASE_URL/$endpoint'),
        headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
        body: {
          fieldName: _selectedStock,
          'quantity': _quantityController.text,
        },
      ).timeout(const Duration(seconds: HTTP_TIMEOUT));

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${_selectedAction} order placed for $_selectedStock'),
            backgroundColor: Colors.green,
          ),
        );
        _quantityController.clear();
        _loadFundDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out'), backgroundColor: Colors.red),
      );
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection'), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F1117),
        title: const Text(
          'Quick Prop',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A82E4).withOpacity(0.15),
            ),
            child: IconButton(
              icon: const Icon(Icons.person, color: Color(0xFF2A82E4)),
              onPressed: () {
                _showConfirmationDialog(
                  'Logout',
                  'Are you sure you want to logout?',
                  () {
                    _priceUpdateTimer?.cancel();
                    _balanceUpdateTimer?.cancel();
                    _positionsUpdateTimer?.cancel();
                    _ordersUpdateTimer?.cancel();
                    _optionsUpdateTimer?.cancel();
                    widget.onLogout();
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF0F1117),
        child: IndexedStack(
          index: _selectedNavIndex,
          children: [
            _buildBuySellScreen(),
            _buildPositionsScreen(),
            _buildOrdersScreen(),
            _buildFuturesScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (index) => setState(() => _selectedNavIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF2A82E4),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Trade'),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Positions'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Futures'),
          ],
        ),
      ),
    );
  }

  Widget _buildBuySellScreen() {
    final portfolioValue = _totalFunds;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio Value',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${portfolioValue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Stock',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            child: DropdownButton<String>(
              value: _selectedStock,
              isExpanded: true,
              underline: const SizedBox(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              dropdownColor: const Color(0xFF1C1F26),
              borderRadius: BorderRadius.circular(10),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              onChanged: (String? value) {
                if (value != null) setState(() => _selectedStock = value);
              },
              items: _stockSymbols.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem(value: value, child: Text(value));
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Last Traded Price',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${(_stockPrices[_selectedStock] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: (_stockPrices[_selectedStock] ?? 0) >= (_previousPrices[_selectedStock] ?? 0)
                        ? const Color(0xFF10B981)
                        : Colors.red,
                  ),
                ),
                Icon(
                  (_stockPrices[_selectedStock] ?? 0) >= (_previousPrices[_selectedStock] ?? 0)
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: (_stockPrices[_selectedStock] ?? 0) >= (_previousPrices[_selectedStock] ?? 0)
                      ? const Color(0xFF10B981)
                      : Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Action',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildActionButton('BUY', const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _buildActionButton('SELL', const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Quantity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildInputField('Enter quantity', Icons.shopping_bag_outlined, _quantityController),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A82E4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Place Order',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color) {
    final isSelected = _selectedAction == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedAction = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(label == 'BUY' ? Icons.trending_up : Icons.trending_down, color: isSelected ? color : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String hint, IconData icon, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF2A82E4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPositionsScreen() {
    if (_cachedPositions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _cachedPositions ?? {};
    final totalPnL = double.tryParse(data['total_pnl'].toString()) ?? 0.0;
    final realizedPnL = double.tryParse(data['total_realized_pnl'].toString()) ?? 0.0;
    final unrealizedPnL = double.tryParse(data['total_unrealized_pnl'].toString()) ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  totalPnL >= 0 ? const Color(0xFF10B981).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  totalPnL >= 0 ? const Color(0xFF10B981).withOpacity(0.05) : Colors.red.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: totalPnL >= 0 ? const Color(0xFF10B981).withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total P&L',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${totalPnL.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: totalPnL >= 0 ? const Color(0xFF10B981) : Colors.red,
                        letterSpacing: -1,
                      ),
                    ),
                    Icon(
                      totalPnL >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: totalPnL >= 0 ? const Color(0xFF10B981) : Colors.red,
                      size: 32,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Realized P&L',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: const Color(0xFF10B981).withOpacity(0.6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₹${realizedPnL.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Unrealized P&L',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.trending_up,
                            size: 16,
                            color: Colors.orange.withOpacity(0.6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₹${unrealizedPnL.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersScreen() {
    if (_cachedOrders == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = _cachedOrders ?? [];

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 48, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text('No orders yet', style: TextStyle(color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );

  }

  Widget _buildOrderCard(dynamic order) {
    final orderType = order['type']?.toString().toUpperCase() ?? 'UNKNOWN';
    final status = order['status'] ?? 'PENDING';
    final isFailed = status == 'FAILED' || status == 'REJECTED';
    
    final quantity = order['quantity'] ?? 0;
    final avgPrice = double.tryParse(order['AVG_price'].toString()) ?? 0.0;
    final totalValue = quantity * avgPrice;
    
    Color statusColor;
    IconData statusIcon;
    
    if (isFailed) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (status == 'COMPLETED') {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_actions;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order['Stock'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '$orderType • Qty: $quantity @ ₹${avgPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(isFailed ? 'FAILED' : status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('₹${totalValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuturesScreen() {
    if (_cachedOptions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _cachedOptions ?? {};
    final spot = data['spot'] ?? 0;
    final options = List<dynamic>.from(data['options'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NIFTY 50 Spot', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                const SizedBox(height: 8),
                Text('₹${spot.toString()}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('NIFTY 50 Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (options.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.inbox, size: 48, color: Color(0xFF6B7280)),
                  const SizedBox(height: 16),
                  Text('No options available', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final symbol = option['symbol'];
                final isCall = option['option_type'] == 'CE';
                final color = isCall ? const Color(0xFF10B981) : Colors.red;
                final ltp = double.tryParse(option['ltp'].toString()) ?? 0.0;
                
                final previousLtp = _previousOptionPrices[symbol] ?? ltp;
                final priceColor = ltp >= previousLtp ? const Color(0xFF10B981) : Colors.red;
                final priceIcon = ltp >= previousLtp ? Icons.trending_up : Icons.trending_down;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${option['symbol']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('Strike: ₹${option['strike']}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: color),
                                ),
                                child: Text(option['option_type'], style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(priceIcon, size: 14, color: priceColor),
                                  const SizedBox(width: 4),
                                  Text('₹${ltp.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: priceColor)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showConfirmationDialog(
                                    'Confirm Buy Option',
                                    'Symbol: ${option['symbol']}\nStrike: ₹${option['strike']}\nPrice: ₹${ltp.toStringAsFixed(2)}',
                                    () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Buy order placed for ${option['symbol']}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('BUY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showConfirmationDialog(
                                    'Confirm Sell Option',
                                    'Symbol: ${option['symbol']}\nStrike: ₹${option['strike']}\nPrice: ₹${ltp.toStringAsFixed(2)}',
                                    () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Sell order placed for ${option['symbol']}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('SELL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchPositions() async {
    try {
      final session = SessionManager();
      if (!session.isLoggedIn) {
        return _cachedPositions ?? {'total_pnl': 0.0, 'total_realized_pnl': 0.0, 'total_unrealized_pnl': 0.0};
      }
      
      final cookie = session.getCookieHeader();
      final response = await http.get(
        Uri.parse('$BASE_URL/position_details'),
        headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
      ).timeout(const Duration(seconds: HTTP_TIMEOUT));
      
      if (response.statusCode == 200) {
        try {
          final doc = html_parser.parse(response.body);
          print('Position details HTML fetched, parsing...');
          
          Map<String, dynamic> data = {
            'total_pnl': 0.0,
            'total_realized_pnl': 0.0,
            'total_unrealized_pnl': 0.0,
            'brokerage': 0.0,
            'exchange_charges': 0.0,
          };
          
          try {
            final rows = doc.querySelectorAll('table tbody tr');
            double totalRealizedPnl = 0.0;
            double totalUnrealizedPnl = 0.0;
            
            for (int i = 0; i < rows.length; i++) {
              final row = rows[i];
              final cells = row.querySelectorAll('td');
              
              if (cells.isEmpty) continue;
              
              final firstCellText = cells[0].text.trim();
              
              if (firstCellText != 'Total' && firstCellText != '' && cells.length >= 6) {
                try {
                  final realizedPnl = double.tryParse(
                    cells[1].text.replaceAll(RegExp(r'[^\d.-]'), '')
                  ) ?? 0.0;
                  
                  final unrealizedPnl = double.tryParse(
                    cells[2].text.replaceAll(RegExp(r'[^\d.-]'), '')
                  ) ?? 0.0;
                  
                  totalRealizedPnl += realizedPnl;
                  totalUnrealizedPnl += unrealizedPnl;
                  
                  print('Stock: $firstCellText, Realized: $realizedPnl, Unrealized: $unrealizedPnl');
                } catch (e) {
                  print('Error parsing stock row: $e');
                }
              }
              
              if (firstCellText == 'Total' && cells.length >= 6) {
                try {
                  final totalPnl = double.tryParse(
                    cells[5].text.replaceAll(RegExp(r'[^\d.-]'), '')
                  ) ?? 0.0;
                  data['total_pnl'] = totalPnl;
                  print('Total P&L found: $totalPnl');
                } catch (e) {
                  print('Error parsing total row: $e');
                }
              }
              
              if (cells.length >= 4 && cells[1].text.contains('Total Orders')) {
                try {
                  final brokerage = double.tryParse(
                    cells[2].text.replaceAll(RegExp(r'[^\d.-]'), '')
                  ) ?? 0.0;
                  
                  final exchangeCharges = double.tryParse(
                    cells[3].text.replaceAll(RegExp(r'[^\d.-]'), '')
                  ) ?? 0.0;
                  
                  data['brokerage'] = brokerage;
                  data['exchange_charges'] = exchangeCharges;
                  print('Brokerage: $brokerage, Exchange Charges: $exchangeCharges');
                } catch (e) {
                  print('Error parsing brokerage/charges: $e');
                }
              }
              
              if (cells.length >= 1 && cells[0].text.trim() == 'Total' && i > rows.length - 3) {
                try {
                  if (cells.length >= 6) {
                    final finalPnl = double.tryParse(
                      cells[5].text.replaceAll(RegExp(r'[^\d.-]'), '')
                    ) ?? 0.0;
                    data['total_pnl'] = finalPnl;
                    print('Final Total P&L: $finalPnl');
                  }
                } catch (e) {
                  print('Error parsing final totals: $e');
                }
              }
            }
            
            if (data['total_realized_pnl'] == 0.0) {
              data['total_realized_pnl'] = totalRealizedPnl;
            }
            if (data['total_unrealized_pnl'] == 0.0) {
              data['total_unrealized_pnl'] = totalUnrealizedPnl;
            }
            
          } catch (e) {
            print('Could not parse P&L from HTML: $e');
          }
          
          print('Positions parsed: $data');
          return data;
        } catch (e) {
          print('Parse error positions: $e');
          return _cachedPositions ?? {'total_pnl': 0.0, 'total_realized_pnl': 0.0, 'total_unrealized_pnl': 0.0};
        }
      }
      return _cachedPositions ?? {'total_pnl': 0.0, 'total_realized_pnl': 0.0, 'total_unrealized_pnl': 0.0};
    } catch (e) {
      print('Error fetching positions: $e');
      return _cachedPositions ?? {'total_pnl': 0.0, 'total_realized_pnl': 0.0, 'total_unrealized_pnl': 0.0};
    }
  }

  Future<List<dynamic>> _fetchOrders() async {
    try {
      final session = SessionManager();
      if (!session.isLoggedIn) {
        return _cachedOrders ?? [];
      }
      
      final cookie = session.getCookieHeader();
      final response = await http.get(
        Uri.parse('$BASE_URL/executed_orders'),
        headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
      ).timeout(const Duration(seconds: HTTP_TIMEOUT));
      
      if (response.statusCode == 200) {
        try {
          final doc = html_parser.parse(response.body);
          print('Orders HTML fetched, parsing...');
          
          List<dynamic> orders = [];
          
          final rows = doc.querySelectorAll('table tbody tr');
          
          for (var row in rows) {
            try {
              final cells = row.querySelectorAll('td');
              if (cells.length >= 7) {
                // Correct column mapping:
                // 0: Time, 1: Type, 2: Product, 3: Quantity, 4: Average Price, 5: Average Value, 6: Order Status
                final stockName = cells[2].text.trim();       // Product (INFY, SUNPHARMA, etc.)
                final orderType = cells[1].text.trim().toLowerCase();  // Type (buy/sell)
                final quantity = int.tryParse(cells[3].text.trim()) ?? 0;  // Quantity
                final avgPrice = double.tryParse(cells[4].text.trim()) ?? 0.0;  // Average Price
                final orderStatus = cells[6].text.trim();     // Order Status
                
                orders.add({
                  'Stock': stockName,
                  'type': orderType,
                  'quantity': quantity,
                  'AVG_price': avgPrice,
                  'order_id': orderStatus,
                  'status': orderStatus == 'order Failed' ? 'FAILED' : 'COMPLETED',
                });
                
                print('Order: $stockName, Type: $orderType, Qty: $quantity, Price: $avgPrice, Status: $orderStatus');
              }
            } catch (e) {
              print('Error parsing order row: $e');
            }
          }
          
          print('Orders parsed: ${orders.length} orders found');
          return orders;
        } catch (e) {
          print('Parse error orders: $e');
          return _cachedOrders ?? [];
        }
      }
      return _cachedOrders ?? [];
    } catch (e) {
      print('Error fetching orders: $e');
      return _cachedOrders ?? [];
    }
  }

  Future<Map<String, dynamic>> _fetchOptions() async {
    try {
      final session = SessionManager();
      if (!session.isLoggedIn) {
        return _cachedOptions ?? {'spot': 0, 'options': []};
      }
      
      final cookie = session.getCookieHeader();
      final response = await http.get(
        Uri.parse('$BASE_URL/get_nifty_options'),
        headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
      ).timeout(const Duration(seconds: HTTP_TIMEOUT));
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Options fetched: ${(data['options'] as List).length} options');
          return data;
        } catch (e) {
          print('Parse error options: $e');
          return _cachedOptions ?? {'spot': 0, 'options': []};
        }
      }
      return _cachedOptions ?? {'spot': 0, 'options': []};
    } catch (e) {
      print('Error fetching options: $e');
      return _cachedOptions ?? {'spot': 0, 'options': []};
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceUpdateTimer?.cancel();
    _balanceUpdateTimer?.cancel();
    _positionsUpdateTimer?.cancel();
    _ordersUpdateTimer?.cancel();
    _optionsUpdateTimer?.cancel();
    super.dispose();
  }
}