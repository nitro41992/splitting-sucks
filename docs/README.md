# Documentation

This directory contains documentation for setting up and configuring the app.

## iOS Documentation

- `ios_setup_guide.md` - Comprehensive guide for setting up the app on iOS devices
- `ios_code_signing_guide.md` - Guide for code signing and provisioning profiles on iOS
- `m1_firebase_setup.md` - Detailed guide for setting up Firebase on M1/M2/M3 Mac computers
- `fix_firebase_ios_build.md` - Quick reference for fixing Firebase iOS build issues

## Android Documentation

- `cross_platform_compatibility.md` - Guide for ensuring compatibility between iOS and Android platforms
  - Contains tasks to verify before merging `ios-setup-local` to `main`
  - Includes Android setup instructions for Windows development environments
  - Lists potential issues and solutions for cross-platform development

## Authentication Documentation

- `google_sign_in_fix.md` - Documentation for fixing GoogleSignIn version conflicts and iOS deployment target issues
  - Details the approach for using Firebase Auth's provider methods for Google Sign-In
  - Explains how to fix iOS deployment target mismatch with Firebase SDK requirements
  - References the utility scripts in `scripts/` that apply these fixes

## Project Status

- `billfie_progress_notes.md` - Developer notes on project progress and roadmap

## Usage

These documents provide step-by-step instructions for various setup and configuration tasks. They reference scripts located in the `scripts/` directory. 