import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/split_manager.dart';
import 'receipt_splitter_ui.dart';
import 'services/mock_data_service.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we should use mock data
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    
    return ChangeNotifierProvider(
      create: (_) => useMockData 
          ? MockDataService.createMockSplitManager() 
          : SplitManager(),
      child: MaterialApp(
        title: 'Billfie',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3), // Primary blue color
            primary: const Color(0xFF2196F3),
            secondary: const Color(0xFF4CAF50), // Secondary green color
            surface: Colors.white,
            background: const Color(0xFFF5F5F5),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 2,
            centerTitle: false,
          ),
        ),
        home: const ReceiptSplitterUI(),
      ),
    );
  }
}
