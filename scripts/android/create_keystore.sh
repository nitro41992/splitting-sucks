#!/bin/bash

# This script creates a keystore for signing the Android app

# Define variables
KEYSTORE_DIR="../../android/app"
KEYSTORE_FILE="$KEYSTORE_DIR/billfie-keystore.jks"
KEY_ALIAS="billfie"
VALIDITY_DAYS=10000

# Check if keystore already exists
if [ -f "$KEYSTORE_FILE" ]; then
  echo "Keystore already exists at $KEYSTORE_FILE"
  echo "If you want to create a new one, please delete the existing one first."
  exit 1
fi

# Make sure the directory exists
mkdir -p "$KEYSTORE_DIR"

# Prompt for keystore password
read -sp "Enter keystore password: " KEYSTORE_PASSWORD
echo
read -sp "Confirm keystore password: " KEYSTORE_PASSWORD_CONFIRM
echo

# Check if passwords match
if [ "$KEYSTORE_PASSWORD" != "$KEYSTORE_PASSWORD_CONFIRM" ]; then
  echo "Passwords don't match. Exiting."
  exit 1
fi

# Prompt for key password
read -sp "Enter key password (press Enter to use the same as keystore password): " KEY_PASSWORD
echo

# If key password is empty, use keystore password
if [ -z "$KEY_PASSWORD" ]; then
  KEY_PASSWORD="$KEYSTORE_PASSWORD"
fi

# Generate keystore
echo "Generating keystore..."
keytool -genkey -v \
  -keystore "$KEYSTORE_FILE" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS" \
  -storepass "$KEYSTORE_PASSWORD" \
  -keypass "$KEY_PASSWORD"

# Check if keystore was generated successfully
if [ $? -eq 0 ]; then
  echo "Keystore generated successfully at $KEYSTORE_FILE"
  
  # Create key.properties file with the correct values
  KEY_PROPERTIES_FILE="../../android/key.properties"
  echo "# This file contains the keys for signing the Android app" > "$KEY_PROPERTIES_FILE"
  echo "storeFile=billfie-keystore.jks" >> "$KEY_PROPERTIES_FILE"
  echo "storePassword=$KEYSTORE_PASSWORD" >> "$KEY_PROPERTIES_FILE"
  echo "keyAlias=$KEY_ALIAS" >> "$KEY_PROPERTIES_FILE"
  echo "keyPassword=$KEY_PASSWORD" >> "$KEY_PROPERTIES_FILE"
  
  echo "Created key.properties file at $KEY_PROPERTIES_FILE"
  echo "IMPORTANT: Keep your keystore and key.properties secure. If you lose them, you won't be able to update your app!"
else
  echo "Error generating keystore."
  exit 1
fi 