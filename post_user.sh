#!/bin/bash

curl -X POST http://localhost:4000/ingest/mutations \
  -H "Content-Type: application/json" \
  -d '{
    "mutations": [
      {
        "type": "insert",
        "modified": {
          "name": "John Doe",
          "pub_key": "\u0003ccff3344"
        },
        "syncMetadata": {
          "relation": "users"
        }
      }
    ]
  }'