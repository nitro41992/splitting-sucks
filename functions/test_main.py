import unittest

# All test classes have been moved to their own respective files:
# - TestHelperFunctions -> test_main_helpers.py
# - TestGenerateThumbnail -> test_generate_thumbnail.py
# - TestParseReceipt -> test_parse_receipt.py
# - TestAssignPeopleToItems -> test_assign_people.py
# - TestTranscribeAudio -> test_transcribe_audio.py

# Your test runner should be configured to discover tests in these new files.
# For example, if you use `python -m unittest discover functions` from the project root,
# it should find them automatically if they follow the `test*.py` pattern.

if __name__ == '__main__':
    # This will attempt to discover and run tests in the current directory 
    # and subdirectories. Ensure your test runner is correctly configured.
    # If you run tests from the `functions` directory directly, e.g. `python -m unittest`
    # it should pick up the new test_*.py files.
    
    # Create a TestLoader instance
    loader = unittest.TestLoader()
    
    # Discover tests in the current directory (where test_*.py files are)
    # The pattern 'test*.py' is the default for discover.
    suite = loader.discover(start_dir='.', pattern='test_*.py')
    
    # Create a TestResult object (optional, for more detailed results)
    # result = unittest.TestResult()
    
    # Run the tests using a TextTestRunner
    runner = unittest.TextTestRunner()
    runner.run(suite)

    # Alternatively, the simpler unittest.main() can also work if it correctly discovers
    # tests in the sibling files. However, explicit discovery can be more reliable.
    # unittest.main()
