import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class DefaultConnector {
  final FirebaseFirestore _firestore;
  
  static final DefaultConnector _instance = DefaultConnector._internal();
  
  factory DefaultConnector() {
    return _instance;
  }
  
  DefaultConnector._internal() : _firestore = FirebaseFirestore.instance;
  
  static DefaultConnector get instance => _instance;

  FirebaseFirestore get firestore => _firestore;
}

