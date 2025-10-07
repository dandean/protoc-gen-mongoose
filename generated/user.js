const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  id: {
    type: String,
    unique: true
  },
  email: {
    type: String,
    required: true
  },
  name: {
    type: String,
    index: true
  }
}, {
  collection: 'users',
  timestamps: true
});

module.exports = mongoose.model('User', UserSchema);
