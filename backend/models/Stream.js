const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const streamSchema = new mongoose.Schema({
  streamCode: {
    type: String,
    required: true,
    unique: true,
    default: () => uuidv4().substring(0, 8).toUpperCase(),
  },
  creator: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  title: {
    type: String,
    required: true,
    trim: true,
  },
  description: {
    type: String,
    default: '',
  },
  isLive: {
    type: Boolean,
    default: true,
  },
  viewers: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  }],
  likes: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  }],
  chatMessages: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    username: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      required: true,
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  }],
  streamUrl: {
    type: String,
    default: '',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  endedAt: {
    type: Date,
  },
});

module.exports = mongoose.model('Stream', streamSchema);

