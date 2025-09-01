#!/bin/bash

curl -X POST http://buckitup.xyz:4403/ingest/mutations \
  -H "Content-Type: application/json" \
  -d '{
    "mutations": [
      {
        "type": "insert",
        "modified": {
          "name": "John Doe",
          "pub_key": "\\x021e01c13a55a4cd36fea3d8b6b9ba7a460d2402fadc0403fd971d8ec6a058b935"
        },
        "syncMetadata": {
          "relation": "users"
        }
      }
    ]
  }'
