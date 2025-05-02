#!/bin/bash

echo "Cleaning Flutter build..."
flutter clean

echo "Getting packages..."
flutter pub get

echo "Building iOS app..."
flutter build ios --no-codesign

echo "iOS app rebuilt successfully. Please run the app again using Xcode or 'flutter run'." 