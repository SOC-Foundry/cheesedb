import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';

// Data Model
class Product {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      price: double.tryParse(data['price'].toString()) ?? 0.0,
    );
  }
}

// State Management
final cartProvider = StateNotifierProvider<CartNotifier, List<Product>>((ref) => CartNotifier());

class CartNotifier extends StateNotifier<List<Product>> {
  CartNotifier() : super([]);

  void add(Product product) {
    state = [...state, product];
  }

  void remove(Product product) {
    state = state.where((p) => p.id != product.id).toList();
  }
}

final searchResultsProvider = StateProvider<List<Product>>((ref) => []);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(ProviderScope(child: CheeseDbApp()));
}

class CheeseDbApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CheeseDB',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LandingPage(),
    );
  }
}

class LandingPage extends ConsumerStatefulWidget {
  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final TextEditingController _searchController = TextEditingController();

  void _searchProducts(String query) {
    if (query.isEmpty) {
      ref.read(searchResultsProvider.notifier).state = [];
      return;
    }

    FirebaseFirestore.instance
        .collection('products')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .get()
        .then((snapshot) {
      final results = snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      ref.read(searchResultsProvider.notifier).state = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('CheeseDB'),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartView()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to the Cheese Database, a collection of cheeses, jams, nuts, berries, meats, and other accouterments to help you build the best charcuterie boards! With everything from the softest, most buttery triple crèmes to the hardest, nuttiest Goudas, we will help satisfy even the most discerning palette! Please search in the field below to get started...',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a cheese...',
                border: OutlineInputBorder(),
              ),
              onChanged: _searchProducts,
            ),
            SizedBox(height: 16),
            if (searchResults.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final product = searchResults[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: product.imageUrl.isNotEmpty
                          ? Image.network(product.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                          : null,
                      title: Text(product.name),
                      subtitle: Text(product.description),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).add(product);
                        },
                        child: Text('Add to Cart'),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class CartView extends ConsumerWidget {
  void _exportCart(BuildContext context, List<Product> cart) {
    final cartText = cart.map((p) => '${p.name} - \$${p.price.toStringAsFixed(2)}').join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cart exported!\n\n$cartText')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final product = cart[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      ref.read(cartProvider.notifier).remove(product);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _exportCart(context, cart),
              child: Text('Export Cart'),
            ),
          ),
        ],
      ),
    );
  }
}