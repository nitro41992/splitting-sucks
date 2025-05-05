import 'dart:io';
import 'package:flutter/material.dart';
import 'receipt_upload_screen.dart';
import 'receipt_review_screen.dart';
import 'voice_assignment_screen.dart';
import 'assignment_review_screen.dart';
import 'final_summary_screen.dart';

class CreateWorkflowScreen extends StatefulWidget {
  const CreateWorkflowScreen({Key? key}) : super(key: key);

  @override
  State<CreateWorkflowScreen> createState() => _CreateWorkflowScreenState();
}

class _CreateWorkflowScreenState extends State<CreateWorkflowScreen> {
  int _currentStep = 0;
  File? _imageFile;
  bool _isLoading = false;
  
  // Define the steps in the workflow
  final List<String> _steps = [
    'Upload',
    'Review',
    'Assign',
    'Split',
    'Summary',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Receipt'),
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                
                return Row(
                  children: [
                    // Step circle
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : isCompleted
                                ? Colors.green
                                : Colors.grey.shade300,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    // Step label
                    if (isActive)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          _steps[index],
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    
                    // Connector line
                    if (index < _steps.length - 1)
                      Container(
                        width: index == _currentStep || index == _currentStep - 1
                            ? 12
                            : 20,
                        height: 2,
                        color: isCompleted
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                  ],
                );
              }),
            ),
          ),
          
          // Current step content
          Expanded(
            child: _buildCurrentStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return ReceiptUploadScreen(
          imageFile: _imageFile,
          isLoading: _isLoading,
          onImageSelected: (file) {
            setState(() {
              _imageFile = file;
            });
          },
          onParseReceipt: () {
            setState(() {
              _isLoading = true;
            });
            // Simulate API call
            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                _isLoading = false;
                _currentStep = 1; // Move to review step
              });
            });
          },
          onRetry: () {
            setState(() {
              _imageFile = null;
            });
          },
        );
      case 1:
        // Just a placeholder for now as we're focusing on the history screen
        return const Center(
          child: Text('Receipt Review - Coming Soon'),
        );
      case 2:
        return const Center(
          child: Text('Voice Assignment - Coming Soon'),
        );
      case 3:
        return const Center(
          child: Text('Split Items - Coming Soon'),
        );
      case 4:
        return const Center(
          child: Text('Final Summary - Coming Soon'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
} 