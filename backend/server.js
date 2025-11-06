const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI;

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('MongoDB connected'))
.catch(err => console.error('MongoDB connection error:', err));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/streams', require('./routes/streams'));
app.use('/api/profiles', require('./routes/profiles'));

app.get('/', (req, res) => {
  res.json({ message: 'VidStream API is running' });
});

const streamRooms = new Map();

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('join-stream', async ({ streamId, userId, userType }) => {
    try {
      socket.join(`stream-${streamId}`);
      console.log(`User ${userId} (${userType}) joined stream ${streamId}`);

      const roomKey = `stream-${streamId}`;
      if (!streamRooms.has(roomKey)) {
        streamRooms.set(roomKey, {
          streamId,
          creator: null,
          viewers: new Set(),
        });
      }

      const room = streamRooms.get(roomKey);
      if (userType === 'creator') {
        room.creator = socket.id;
      } else {
        room.viewers.add(socket.id);
      }

      socket.emit('joined-stream', { streamId, success: true });
      
      if (userType === 'creator') {
        socket.emit('waiting-for-viewers');
      } else if (room.creator) {
        io.to(room.creator).emit('viewer-joined', { viewerId: socket.id });
      }
    } catch (error) {
      socket.emit('error', { message: 'Failed to join stream' });
    }
  });

  socket.on('offer', ({ streamId, offer, targetId }) => {
    const room = streamRooms.get(`stream-${streamId}`);
    if (room && room.creator === socket.id) {
      io.to(targetId).emit('offer', { offer, fromId: socket.id });
    }
  });

  socket.on('answer', ({ streamId, answer, targetId }) => {
    const room = streamRooms.get(`stream-${streamId}`);
    if (room && room.viewers.has(socket.id)) {
      io.to(targetId).emit('answer', { answer, fromId: socket.id });
    }
  });

  socket.on('ice-candidate', ({ streamId, candidate, targetId }) => {
    io.to(targetId).emit('ice-candidate', { candidate, fromId: socket.id });
  });

  socket.on('leave-stream', ({ streamId, userId, userType }) => {
    const roomKey = `stream-${streamId}`;
    const room = streamRooms.get(roomKey);
    
    if (room) {
      if (userType === 'creator') {
        io.to(roomKey).emit('stream-ended');
        streamRooms.delete(roomKey);
      } else {
        room.viewers.delete(socket.id);
        if (room.creator) {
          io.to(room.creator).emit('viewer-left', { viewerId: socket.id });
        }
      }
    }
    
    socket.leave(roomKey);
    console.log(`User ${userId} left stream ${streamId}`);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
    
    for (const [roomKey, room] of streamRooms.entries()) {
      if (room.creator === socket.id) {
        io.to(roomKey).emit('stream-ended');
        streamRooms.delete(roomKey);
      } else if (room.viewers.has(socket.id)) {
        room.viewers.delete(socket.id);
        if (room.creator) {
          io.to(room.creator).emit('viewer-left', { viewerId: socket.id });
        }
      }
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Accessible at http://localhost:${PORT} or http://0.0.0.0:${PORT}`);
  console.log(`WebSocket server ready for WebRTC signaling`);
});

