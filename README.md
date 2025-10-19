# ProtoHelper Free-Pacal — Lightweight Protobuf Serializer

## Overview

`ProtoHelper` is a lightweight helper for **serializing and deserializing** classes into **Google Protocol Buffers (Protobuf)** binary format — without needing to use the `protoc` compiler to generate schema files.

This makes it ideal for small projects or dynamic systems where you want to handle Protobuf data directly, without maintaining `.proto` definitions.

---

## ⚙️ How It Works

Unlike text-based formats (like JSON), **Protobuf** encodes data in a compact binary format.  
Since no schema is used, **the order of fields is critical** — fields are written and read in the exact order they appear in the class.

If the order changes, the binary structure becomes invalid and cannot be properly deserialized.

---

## 🧩 Example Structure

In the example, we define three simple classes:

- **`TContact`** – Represents a contact person  
- **`TAddress`** – Represents a postal address  
- **`TCompany`** – Represents a company that contains `TAddress` and a list of `TContact`

Each class can be serialized using `ProtoHelper.Serialize()` and deserialized using `ProtoHelper.Deserialize()`.

---

## 💾 File Operations

The example demonstrates how to:

1. **Serialize** a class instance (including nested objects)
2. **Save** the binary data to a `.pb` file  
3. **Read** the `.pb` file from disk  
4. **Deserialize** it back into a class instance

---

## 🧪 Testing the Output

You can inspect and decode the `.pb` files generated with this helper at:  
👉 [https://protobuf-decoder.netlify.app/](https://protobuf-decoder.netlify.app/)

This tool allows you to view the raw Protobuf structure and verify that your serialization is working as expected.

---

## 🚀 Benefits

- No `.proto` schema or `protoc` compiler needed  
- Easy to integrate into existing projects  
- Supports nested classes and collections  
- Portable binary format compatible with other Protobuf tools

---

## 📘 Notes

- Maintain **consistent field order** between serialization and deserialization.  
- Use the same class structure across all environments reading or writing the data.  
- Any change in field order or type may break compatibility with previously saved `.pb` files.

---

😉 *Simple, schema-free, and powerful — that’s `ProtoHelper`.*
