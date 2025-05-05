const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

// Check multiple possible locations for .env file
let userId = null;
const possibleEnvPaths = [
  path.resolve(__dirname, '.env'),               // Current directory
  path.resolve(__dirname, '../.env'),            // One level up (functions)
  path.resolve(__dirname, '../../.env'),         // Two levels up (project root)
];

console.log('Searching for .env file in:');
for (const envPath of possibleEnvPaths) {
  console.log(`- ${envPath}`);
  if (fs.existsSync(envPath)) {
    console.log(`Found .env file at: ${envPath}`);
    const envConfig = dotenv.parse(fs.readFileSync(envPath));
    if (envConfig.FIREBASE_USER_ID) {
      userId = envConfig.FIREBASE_USER_ID;
      console.log(`Loaded FIREBASE_USER_ID from ${envPath}`);
      break;
    } else {
      console.log(`File exists but FIREBASE_USER_ID not found in ${envPath}`);
    }
  }
}

// Fall back to environment variable if .env didn't have it
if (!userId) {
  userId = process.env.FIREBASE_USER_ID;
  if (userId) {
    console.log('Loaded FIREBASE_USER_ID from environment variable');
  }
}

// Check if we have a user ID
if (!userId) {
  console.error('Error: FIREBASE_USER_ID not found in any .env file or environment variables.');
  console.error('Please either:');
  console.error('1. Add FIREBASE_USER_ID=your_user_id to your .env file, or');
  console.error('2. Set it as an environment variable:');
  console.error('   export FIREBASE_USER_ID=your_user_id        (for Mac/Linux)');
  console.error('   set FIREBASE_USER_ID=your_user_id           (for Windows CMD)');
  console.error('   $env:FIREBASE_USER_ID="your_user_id"        (for Windows PowerShell)');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Create mock receipts
async function createMockData() {
  console.log('Creating mock data for user:', userId);

  const receiptData = [
    {
      id: 'receipt1',
      image_uri: 'gs://billfie.firebasestorage.app/receipts/PXL_20240815_225730738.jpg',
      created_at: admin.firestore.Timestamp.fromDate(new Date()),
      updated_at: admin.firestore.Timestamp.fromDate(new Date()),
      userId: userId,
      restaurant_name: 'Pizza Place',
      status: 'completed',
      total_amount: 75.50,
      receipt_data: {
        items: [
          {id: 0, item: 'Pizza', quantity: 1, price: 15.99},
          {id: 1, item: 'Salad', quantity: 1, price: 8.99},
          {id: 2, item: 'Garlic Bread', quantity: 2, price: 5.99},
          {id: 3, item: 'Soda', quantity: 3, price: 2.99}
        ],
        subtotal: 45.92
      },
      transcription: 'Pizza and salad for dinner',
      people: ['John', 'Sarah', 'Mike'],
      person_totals: [
        {name: 'John', total: 25.50},
        {name: 'Sarah', total: 22.00},
        {name: 'Mike', total: 28.00}
      ],
      split_manager_state: {
        people: [
          {
            id: 'John',
            name: 'John',
            assignedItems: [{id: 0, item: 'Pizza', quantity: 1, price: 15.99}]
          },
          {
            id: 'Sarah',
            name: 'Sarah',
            assignedItems: [{id: 1, item: 'Salad', quantity: 1, price: 8.99}]
          },
          {
            id: 'Mike',
            name: 'Mike',
            assignedItems: [{id: 3, item: 'Soda', quantity: 3, price: 2.99}]
          }
        ],
        sharedItems: [
          {
            id: 2,
            item: 'Garlic Bread',
            quantity: 2,
            price: 5.99,
            shared_by: ['John', 'Sarah', 'Mike']
          }
        ],
        unassignedItems: [],
        tipAmount: 15.00,
        taxAmount: 3.75,
        subtotal: 45.92,
        total: 64.67
      }
    },
    {
      id: 'receipt2',
      image_uri: 'gs://billfie.firebasestorage.app/receipts/PXL_20241207_220416408.MP.jpg',
      created_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)),
      updated_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)),
      userId: userId,
      restaurant_name: 'Burger Joint',
      status: 'completed',
      total_amount: 42.75,
      receipt_data: {
        items: [
          {id: 0, item: 'Burger', quantity: 2, price: 12.99},
          {id: 1, item: 'Fries', quantity: 2, price: 3.99},
          {id: 2, item: 'Milkshake', quantity: 1, price: 5.99}
        ],
        subtotal: 39.95
      },
      transcription: 'Lunch with Alex',
      people: ['John', 'Alex'],
      person_totals: [
        {name: 'John', total: 21.50},
        {name: 'Alex', total: 21.25}
      ],
      split_manager_state: {
        people: [
          {
            id: 'John',
            name: 'John',
            assignedItems: [
              {id: 0, item: 'Burger', quantity: 1, price: 12.99},
              {id: 1, item: 'Fries', quantity: 1, price: 3.99}
            ]
          },
          {
            id: 'Alex',
            name: 'Alex',
            assignedItems: [
              {id: 0, item: 'Burger', quantity: 1, price: 12.99},
              {id: 1, item: 'Fries', quantity: 1, price: 3.99}
            ]
          }
        ],
        sharedItems: [
          {
            id: 2,
            item: 'Milkshake',
            quantity: 1,
            price: 5.99,
            shared_by: ['John', 'Alex']
          }
        ],
        unassignedItems: [],
        tipAmount: 2.00,
        taxAmount: 0.80,
        subtotal: 39.95,
        total: 42.75
      }
    },
    {
      id: 'draft1',
      image_uri: 'gs://billfie.firebasestorage.app/receipts/PXL_20250419_011719007.jpg',
      created_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
      updated_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
      userId: userId,
      restaurant_name: 'Draft Receipt',
      status: 'draft',
      total_amount: 32.50,
      receipt_data: {
        items: [
          {id: 0, item: 'Coffee', quantity: 2, price: 4.50},
          {id: 1, item: 'Pastry', quantity: 2, price: 3.25},
          {id: 2, item: 'Sandwich', quantity: 1, price: 9.99}
        ],
        subtotal: 25.49
      },
      transcription: null,
      people: ['John', 'Emma'],
      person_totals: [],
      split_manager_state: {
        people: [
          {id: 'John', name: 'John', assignedItems: []},
          {id: 'Emma', name: 'Emma', assignedItems: []}
        ],
        sharedItems: [],
        unassignedItems: [
          {id: 0, item: 'Coffee', quantity: 2, price: 4.50},
          {id: 1, item: 'Pastry', quantity: 2, price: 3.25},
          {id: 2, item: 'Sandwich', quantity: 1, price: 9.99}
        ],
        tipAmount: 5.00,
        taxAmount: 2.01,
        subtotal: 25.49,
        total: 32.50
      }
    }
  ];

  // Check if receipts already exist
  console.log('Checking for existing data...');
  const existingDocs = await db.collection(`users/${userId}/receipts`).limit(1).get();
  
  if (!existingDocs.empty) {
    console.log('Found existing receipts. Do you want to clear them before adding new ones? (y/n)');
    
    // Simple readline implementation for confirming
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const answer = await new Promise(resolve => {
      readline.question('> ', (answer) => {
        readline.close();
        resolve(answer.toLowerCase());
      });
    });
    
    if (answer === 'y') {
      console.log('Clearing existing receipts...');
      const snapshot = await db.collection(`users/${userId}/receipts`).get();
      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`Deleted ${snapshot.size} existing receipts.`);
    } else {
      console.log('Keeping existing receipts.');
    }
  }

  // Create a batch operation
  const batch = db.batch();
  
  // Add each receipt to batch
  for (const receipt of receiptData) {
    const id = receipt.id;
    delete receipt.id; // Remove ID from the document data
    const docRef = db.collection(`users/${userId}/receipts`).doc(id);
    batch.set(docRef, receipt);
  }
  
  // Commit the batch
  await batch.commit();
  console.log(`Created ${receiptData.length} mock receipts for user: ${userId}`);
}

// Run the function
createMockData()
  .then(() => console.log('Script completed successfully'))
  .catch(error => console.error('Error creating mock data:', error))
  .finally(() => process.exit()); 