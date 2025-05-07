**Step-by-Step:**

1. **Check Port Availability**
   - Ensure no other services are using the ports required by Firebase emulators.
   - You can check running processes on ports with commands like:
     ```sh
     # On Windows
     netstat -ano | findstr :8081
     # On Mac/Linux
     lsof -i :8081
     ```
   - If necessary, kill processes using required ports or update `firebase.json` to use alternative ports.

2. **Start the Firebase Emulator Suite**
   - From the project root, run:
     ```sh
     firebase emulators:start
     ```
   - This will start the Firestore emulator (and any other configured emulators) using ports defined in `firebase.json`.
   - Confirm the emulators are running by accessing the UI at http://localhost:4000

3. **Open a New Terminal for Seeding**
   - Keep the emulator running in its own terminal window/tab.
   - Open a new terminal for the seeding process.
   - Navigate to the `functions/` directory:
     ```sh
     cd functions
     ```

4. **Set the Firestore Emulator Environment Variable**
   - **IMPORTANT**: This tells the Python script to write to the emulator instead of production.
   - On Windows (Command Prompt):
     ```sh
     set FIRESTORE_EMULATOR_HOST=localhost:8081
     ```
   - On Windows (PowerShell):
     ```sh
     $env:FIRESTORE_EMULATOR_HOST="localhost:8081"
     ```
   - On Mac/Linux or Git Bash:
     ```sh
     export FIRESTORE_EMULATOR_HOST=localhost:8081
     ```

5. **Run the Seeding Script**
   - Use the appropriate path to your emulator seed data (relative to the functions directory):
     ```sh
     python init_firestore_config.py --admin-uid=admin --cred-path=billfie-firebase-adminsdk-fbsvc-3478b1c3d9.json --seed-data-dir=../emulator_seed_data
     ```
   - You should see output confirming that prompt and model configurations have been loaded from files and set for each workflow.

6. **Verify**
   - Visit [http://localhost:4000/firestore](http://localhost:4000/firestore) in your browser to confirm the seeded data is present in the emulator.
   - Check the `configs` collection to see if prompts and models for each workflow were successfully added.

**Troubleshooting Emulator Configuration:**

1. **Port Conflicts**
   - If you encounter port conflicts, edit your `firebase.json` file to specify different ports:
     ```json
     "emulators": {
       "firestore": {
         "host": "localhost",
         "port": 8081
       },
       // Other emulator configurations...
     }
     ```