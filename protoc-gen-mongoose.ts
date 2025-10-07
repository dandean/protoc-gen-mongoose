#!/usr/bin/env -S npx tsx

// Protoc plugin that generates Mongoose schemas from protobuf definitions
// Uses @bufbuild/protoplugin framework

import { createEcmaScriptPlugin, runNodeJs, type Schema } from "@bufbuild/protoplugin";
import { getOption, hasOption } from "@bufbuild/protobuf";
import {
  mongoose_index,
  mongoose_unique,
  mongoose_required,
  mongoose_collection
} from "./generated/pb/mongoose/options/v1/mongoose_options_pb.js";

const protocGenMongoose = createEcmaScriptPlugin({
  name: "protoc-gen-mongoose",
  version: "v1.0.0",
  generateTs,
});

function generateTs(schema: Schema) {
  // Process each file in the schema
  for (const file of schema.files) {
    // Skip files that don't have messages or are option files
    if (file.messages.length === 0 || file.name.includes('options')) {
      continue;
    }

    // Process each message in the file
    for (const message of file.messages) {
      const f = schema.generateFile(`${message.name.toLowerCase()}.ts`);
      generateMongooseSchema(f, file, message);
    }
  }
}

runNodeJs(protocGenMongoose);

function generateMongooseSchema(f: any, file: any, message: any) {
  f.preamble(file);
  f.print("import {Schema} from 'mongoose';");
  f.print('\n\n');
  f.print(`export const ${message.name}Schema = new Schema({`);

  // Generate fields
  message.fields.forEach((field: any, index: number) => {
    const mongooseType = getMongooseType(field);
    const fieldOptions = getFieldOptions(field);

    if (Object.keys(fieldOptions).length > 0) {
      f.print(`  ${field.name}: {`);
      f.print(`    type: ${mongooseType}`);

      Object.entries(fieldOptions).forEach(([key, value]) => {
        f.print(`,    ${key}: ${value}`);
      });

      f.print('  }' + (index < message.fields.length - 1 ? ',' : ''));
    } else {
      f.print(`  ${field.name}: ${mongooseType}` + (index < message.fields.length - 1 ? ',' : ''));
    }
  });

  // Get collection name from message options
  const collectionName = getCollectionName(message);

  f.print('}, {');
  f.print(`  collection: '${collectionName}',`);
  f.print('  timestamps: true');
  f.print('});');
}

function getMongooseType(field: any): string {
  switch (field.fieldKind) {
    case "scalar":
      switch (field.scalar) {
        case 9: // STRING
          return 'String';
        case 1: // DOUBLE
        case 2: // FLOAT
        case 3: // INT64
        case 4: // UINT64
        case 5: // INT32
        case 13: // UINT32
        case 17: // SINT32
        case 18: // SINT64
        case 15: // SFIXED32
        case 16: // SFIXED64
        case 6: // FIXED64
        case 7: // FIXED32
          return 'Number';
        case 8: // BOOL
          return 'Boolean';
        case 12: // BYTES
          return 'Buffer';
        default:
          return 'String';
      }
    case "message":
      // Handle well-known types
      if (field.message?.typeName === ".google.protobuf.Timestamp") {
        return 'Date';
      }
      return 'mongoose.Schema.Types.Mixed';
    case "enum":
      return 'String';
    default:
      return 'String';
  }
}

function getFieldOptions(field: any): Record<string, any> {
  const options: Record<string, any> = {};

  // Use the proper protobuf extension API
  if (hasOption(field, mongoose_unique) && getOption(field, mongoose_unique)) {
    options.unique = true;
  }
  if (hasOption(field, mongoose_required) && getOption(field, mongoose_required)) {
    options.required = true;
  }
  if (hasOption(field, mongoose_index) && getOption(field, mongoose_index)) {
    options.index = true;
  }

  return options;
}

function getCollectionName(message: any): string {
  // Use the proper protobuf extension API
  if (hasOption(message, mongoose_collection)) {
    return getOption(message, mongoose_collection);
  }

  // Default to pluralized lowercase message name
  return message.name.toLowerCase() + 's';
}
