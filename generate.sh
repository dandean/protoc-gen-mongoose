#!/bin/bash

# Clean up
rm -rf generated

# Step 1: Generate protobuf TypeScript files only
echo "Generating protobuf TypeScript files..."
npx buf generate --template '{"version":"v2","plugins":[{"local":"protoc-gen-es","out":"generated/pb","opt":"target=ts"}]}'

# Step 2: Generate Mongoose schemas
echo "Generating Mongoose schemas..."
npx buf generate --template '{"version":"v2","plugins":[{"local":"./protoc-gen-mongoose.ts","out":"generated/mongoose"}]}'

echo "Done!"
