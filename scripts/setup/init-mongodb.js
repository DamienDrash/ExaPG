// MongoDB Initialisierungsskript für ExaPG Virtual Schemas Demo

// Wähle die Datenbank aus
db = db.getSiblingDB('testdb');

// Erstelle Benutzersammlung
db.users.drop();
db.createCollection('users');

db.users.insertMany([
  {
    _id: 1,
    name: "Max Muster",
    email: "max.muster@example.com",
    age: 35,
    address: {
      street: "Musterstraße 1",
      city: "Berlin",
      zip: "12345",
      country: "Deutschland"
    },
    interests: ["Datenbanken", "PostgreSQL", "ExaPG"],
    joined_at: new Date("2023-01-15"),
    is_active: true,
    metadata: {
      last_login: new Date(),
      login_count: 42,
      preferences: {
        theme: "dark",
        notifications: true
      }
    }
  },
  {
    _id: 2,
    name: "Anna Schmidt",
    email: "anna.schmidt@example.com",
    age: 28,
    address: {
      street: "Schmidtweg 42",
      city: "Hamburg",
      zip: "23456",
      country: "Deutschland"
    },
    interests: ["Data Science", "Machine Learning", "SQL"],
    joined_at: new Date("2023-02-20"),
    is_active: true,
    metadata: {
      last_login: new Date(),
      login_count: 23,
      preferences: {
        theme: "light",
        notifications: false
      }
    }
  },
  {
    _id: 3,
    name: "Peter Müller",
    email: "peter.mueller@example.com",
    age: 42,
    address: {
      street: "Müllerplatz 3",
      city: "München",
      zip: "34567",
      country: "Deutschland"
    },
    interests: ["Business Intelligence", "Data Warehousing"],
    joined_at: new Date("2022-11-10"),
    is_active: false,
    metadata: {
      last_login: new Date(new Date().setDate(new Date().getDate() - 60)),
      login_count: 5,
      preferences: {
        theme: "system",
        notifications: true
      }
    }
  }
]);

// Erstelle Produktsammlung
db.products.drop();
db.createCollection('products');

db.products.insertMany([
  {
    _id: 1,
    name: "ExaPG T-Shirt",
    description: "T-Shirt mit ExaPG Logo",
    price: 19.99,
    category: "Bekleidung",
    attributes: {
      size: ["S", "M", "L", "XL"],
      color: ["Schwarz", "Weiß", "Blau"],
      material: "100% Baumwolle"
    },
    stock: {
      quantity: 100,
      warehouse: "Berlin"
    },
    tags: ["ExaPG", "T-Shirt", "Merchandise"],
    created_at: new Date()
  },
  {
    _id: 2,
    name: "PostgreSQL Tasse",
    description: "Kaffeetasse mit PostgreSQL Elefant",
    price: 9.99,
    category: "Geschenke",
    attributes: {
      capacity: "300ml",
      color: ["Weiß", "Blau"],
      dishwasher_safe: true
    },
    stock: {
      quantity: 50,
      warehouse: "Hamburg"
    },
    tags: ["PostgreSQL", "Tasse", "Kaffee", "Merchandise"],
    created_at: new Date()
  },
  {
    _id: 3,
    name: "SQL Lehrbuch",
    description: "SQL für Anfänger und Fortgeschrittene",
    price: 29.99,
    category: "Bücher",
    attributes: {
      pages: 450,
      author: "Datenbank Experte",
      publisher: "ExaPG Verlag",
      isbn: "978-3-16-148410-0"
    },
    stock: {
      quantity: 25,
      warehouse: "Frankfurt"
    },
    tags: ["SQL", "Lehrbuch", "Datenbanken", "Bildung"],
    created_at: new Date()
  }
]);

// Erstelle Bestellungssammlung
db.orders.drop();
db.createCollection('orders');

db.orders.insertMany([
  {
    _id: 1,
    user_id: 1,
    order_date: new Date(new Date().setDate(new Date().getDate() - 10)),
    status: "completed",
    items: [
      {
        product_id: 1,
        quantity: 2,
        price: 19.99
      }
    ],
    shipping: {
      address: "Musterstraße 1, 12345 Berlin, Deutschland",
      tracking_number: "TRK123456789",
      carrier: "DHL"
    },
    payment: {
      method: "Kreditkarte",
      total: 39.98,
      currency: "EUR",
      status: "bezahlt"
    }
  },
  {
    _id: 2,
    user_id: 2,
    order_date: new Date(new Date().setDate(new Date().getDate() - 5)),
    status: "shipped",
    items: [
      {
        product_id: 3,
        quantity: 1,
        price: 29.99
      },
      {
        product_id: 2,
        quantity: 3,
        price: 9.99
      }
    ],
    shipping: {
      address: "Schmidtweg 42, 23456 Hamburg, Deutschland",
      tracking_number: "TRK987654321",
      carrier: "DPD"
    },
    payment: {
      method: "PayPal",
      total: 59.97,
      currency: "EUR",
      status: "bezahlt"
    }
  },
  {
    _id: 3,
    user_id: 1,
    order_date: new Date(),
    status: "pending",
    items: [
      {
        product_id: 2,
        quantity: 1,
        price: 9.99
      }
    ],
    shipping: {
      address: "Musterstraße 1, 12345 Berlin, Deutschland",
      tracking_number: null,
      carrier: null
    },
    payment: {
      method: "Banküberweisung",
      total: 9.99,
      currency: "EUR",
      status: "ausstehend"
    }
  }
]);

// Erstelle Indizes für bessere Abfrageleistung
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "is_active": 1 });
db.products.createIndex({ "category": 1 });
db.products.createIndex({ "tags": 1 });
db.orders.createIndex({ "user_id": 1 });
db.orders.createIndex({ "status": 1 });
db.orders.createIndex({ "order_date": 1 });

// Ausgabe der erstellten Sammlungen
print("MongoDB-Daten für Virtual Schemas Demo wurden erfolgreich initialisiert.");
print("Folgende Sammlungen wurden erstellt:");
print(" - users: " + db.users.countDocuments() + " Dokumente");
print(" - products: " + db.products.countDocuments() + " Dokumente");
print(" - orders: " + db.orders.countDocuments() + " Dokumente"); 