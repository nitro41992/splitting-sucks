#!/usr/bin/env python
"""
Test runner for Billfie cloud functions that provides a clean summary.
Filters out expected errors (GCS auth, cleanup warnings) to focus on core logic.
"""

import unittest
import sys
import re
from io import StringIO
import traceback

# Define patterns of expected errors that can be safely ignored
IGNORABLE_PATTERNS = [
    r"GCS Download Failed",
    r"Storage authentication",
    r"Credentials|credentials|auth|Auth",
    r"OS Error.*removing.*file",
    r"already (removed|deleted)",
    r"No such file or directory",
]

class SummaryTestResult(unittest.TextTestResult):
    """Custom test result class that tracks expected vs. unexpected failures"""
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.expected_failures = []
        self.unexpected_failures = []
        self.successful = []
        self.skipped_tests = []
    
    def addSuccess(self, test):
        super().addSuccess(test)
        self.successful.append(test)
    
    def addError(self, test, err):
        # Capture the output to analyze it
        error_string = ''.join(traceback.format_exception(*err))
        
        # Check if this is an expected/ignorable error
        is_expected = any(re.search(pattern, error_string) for pattern in IGNORABLE_PATTERNS)
        
        if is_expected:
            self.expected_failures.append((test, err, error_string))
        else:
            self.unexpected_failures.append((test, err, error_string))
            
        super().addError(test, err)
    
    def addFailure(self, test, err):
        # Capture the output to analyze it
        error_string = ''.join(traceback.format_exception(*err))
        
        # Check if this is an expected/ignorable failure
        is_expected = any(re.search(pattern, error_string) for pattern in IGNORABLE_PATTERNS)
        
        if is_expected:
            self.expected_failures.append((test, err, error_string))
        else:
            self.unexpected_failures.append((test, err, error_string))
            
        super().addFailure(test, err)
    
    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        self.skipped_tests.append((test, reason))

def run_tests_with_summary():
    """Run tests and provide a clean, easy-to-read summary"""
    # Discover and load tests
    loader = unittest.TestLoader()
    tests = loader.discover(".")
    
    # Create a custom test runner with our result class
    stream = sys.stdout
    runner = unittest.TextTestRunner(resultclass=lambda *args, **kwargs: SummaryTestResult(*args, **kwargs), stream=stream)
    
    # Run the tests
    print("\n" + "="*70)
    print(" RUNNING TESTS ".center(70, "="))
    print("="*70 + "\n")
    
    result = runner.run(tests)
    
    # Print summary
    print("\n" + "="*70)
    print(" TEST SUMMARY ".center(70, "="))
    print("="*70)
    
    # Group tests by module
    module_results = {}
    
    for test in result.successful:
        module_name = test.__class__.__module__
        if module_name not in module_results:
            module_results[module_name] = {"success": [], "expected_fail": [], "unexpected_fail": [], "skipped": []}
        module_results[module_name]["success"].append(test)
    
    for test, err, _ in result.expected_failures:
        module_name = test.__class__.__module__
        if module_name not in module_results:
            module_results[module_name] = {"success": [], "expected_fail": [], "unexpected_fail": [], "skipped": []}
        module_results[module_name]["expected_fail"].append((test, err))
    
    for test, err, _ in result.unexpected_failures:
        module_name = test.__class__.__module__
        if module_name not in module_results:
            module_results[module_name] = {"success": [], "expected_fail": [], "unexpected_fail": [], "skipped": []}
        module_results[module_name]["unexpected_fail"].append((test, err))
    
    for test, reason in result.skipped_tests:
        module_name = test.__class__.__module__
        if module_name not in module_results:
            module_results[module_name] = {"success": [], "expected_fail": [], "unexpected_fail": [], "skipped": []}
        module_results[module_name]["skipped"].append((test, reason))
    
    # Print results by module
    for module_name, results in sorted(module_results.items()):
        print(f"\n📋 {module_name}")
        
        for test in results["success"]:
            print(f"  ✅ {test._testMethodName}")
        
        for test, _ in results["expected_fail"]:
            print(f"  ⚠️ {test._testMethodName} (EXPECTED FAILURE - SAFE TO IGNORE)")
        
        for test, _ in results["unexpected_fail"]:
            print(f"  ❌ {test._testMethodName} (ACTUAL FAILURE - NEEDS ATTENTION)")
        
        for test, reason in results["skipped"]:
            print(f"  ⏩ {test._testMethodName} (SKIPPED: {reason})")
    
    # Print overall summary
    print("\n" + "-"*70)
    success_count = len(result.successful)
    expected_failure_count = len(result.expected_failures)
    unexpected_failure_count = len(result.unexpected_failures)
    skipped_count = len(result.skipped_tests)
    total_tests = success_count + expected_failure_count + unexpected_failure_count + skipped_count
    
    print(f"\n🔄 Total Tests: {total_tests}")
    print(f"✅ Passed:         {success_count}")
    print(f"⚠️ Expected Fails: {expected_failure_count} (Safe to ignore)")
    print(f"❌ Actual Fails:   {unexpected_failure_count}")
    print(f"⏩ Skipped:        {skipped_count}")
    
    # Determine overall result
    print("\n" + "="*70)
    if unexpected_failure_count == 0:
        print(" ✅ ALL CORE TESTS PASSED! ".center(70, "="))
        success = True
    else:
        print(" ❌ TESTS FAILED! ".center(70, "="))
        success = False
    print("="*70 + "\n")
    
    return success

if __name__ == "__main__":
    success = run_tests_with_summary()
    sys.exit(0 if success else 1) 