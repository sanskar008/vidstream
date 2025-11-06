const express = require('express');
const Stream = require('../models/Stream');
const auth = require('../middleware/auth');

const router = express.Router();

router.post('/create', auth, async (req, res) => {
  try {
    if (req.user.userType !== 'creator') {
      return res.status(403).json({ message: 'Only creators can create streams' });
    }

    const { title, description } = req.body;

    if (!title) {
      return res.status(400).json({ message: 'Title is required' });
    }

    const stream = new Stream({
      creator: req.user._id,
      title,
      description: description || '',
    });

    await stream.save();
    await stream.populate('creator', 'username');

    res.status(201).json({
      stream: {
        id: stream._id,
        streamCode: stream.streamCode,
        title: stream.title,
        description: stream.description,
        creator: stream.creator,
        isLive: stream.isLive,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/live', async (req, res) => {
  try {
    const streams = await Stream.find({ isLive: true })
      .populate('creator', 'username')
      .sort({ createdAt: -1 });

    res.json({
      streams: streams.map(stream => ({
        id: stream._id,
        streamCode: stream.streamCode,
        title: stream.title,
        description: stream.description,
        creator: {
          id: stream.creator._id,
          username: stream.creator.username,
        },
        viewers: stream.viewers.length,
        likes: stream.likes.length,
        createdAt: stream.createdAt,
      })),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/code/:streamCode', async (req, res) => {
  try {
    const stream = await Stream.findOne({
      streamCode: req.params.streamCode.toUpperCase(),
      isLive: true,
    }).populate('creator', 'username');

    if (!stream) {
      return res.status(404).json({ message: 'Stream not found or not live' });
    }

    res.json({
      stream: {
        id: stream._id,
        streamCode: stream.streamCode,
        title: stream.title,
        description: stream.description,
        creator: {
          id: stream.creator._id,
          username: stream.creator.username,
        },
        viewers: stream.viewers.length,
        likes: stream.likes.length,
        createdAt: stream.createdAt,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/like/:streamId', auth, async (req, res) => {
  try {
    const stream = await Stream.findById(req.params.streamId);

    if (!stream || !stream.isLive) {
      return res.status(404).json({ message: 'Stream not found or not live' });
    }

    const userId = req.user._id;
    const isLiked = stream.likes.some(
      id => id.toString() === userId.toString()
    );

    if (isLiked) {
      stream.likes = stream.likes.filter(
        id => id.toString() !== userId.toString()
      );
      await stream.save();
      
      // Broadcast like update via socket
      const io = req.app.get('io');
      if (io) {
        io.to(`stream-${stream._id}`).emit('like-updated', {
          streamId: stream._id.toString(),
          likesCount: stream.likes.length,
        });
      }
      
      res.json({ 
        message: 'Unliked stream successfully',
        liked: false,
        likesCount: stream.likes.length,
      });
    } else {
      stream.likes.push(userId);
      await stream.save();
      
      // Broadcast like update via socket
      const io = req.app.get('io');
      if (io) {
        io.to(`stream-${stream._id}`).emit('like-updated', {
          streamId: stream._id.toString(),
          likesCount: stream.likes.length,
        });
      }
      
      res.json({ 
        message: 'Liked stream successfully',
        liked: true,
        likesCount: stream.likes.length,
      });
    }
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/like-status/:streamId', auth, async (req, res) => {
  try {
    const stream = await Stream.findById(req.params.streamId);

    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }

    const userId = req.user._id;
    const isLiked = stream.likes.some(
      id => id.toString() === userId.toString()
    );

    res.json({
      liked: isLiked,
      likesCount: stream.likes.length,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/join/:streamId', auth, async (req, res) => {
  try {
    const stream = await Stream.findById(req.params.streamId);

    if (!stream || !stream.isLive) {
      return res.status(404).json({ message: 'Stream not found or not live' });
    }

    if (!stream.viewers.includes(req.user._id)) {
      stream.viewers.push(req.user._id);
      await stream.save();
    }

    res.json({ message: 'Joined stream successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/end/:streamId', auth, async (req, res) => {
  try {
    if (req.user.userType !== 'creator') {
      return res.status(403).json({ message: 'Only creators can end streams' });
    }

    const stream = await Stream.findById(req.params.streamId);

    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }

    if (stream.creator.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not authorized to end this stream' });
    }

    stream.isLive = false;
    stream.endedAt = new Date();
    await stream.save();

    res.json({ message: 'Stream ended successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/resume/:streamId', auth, async (req, res) => {
  try {
    if (req.user.userType !== 'creator') {
      return res.status(403).json({ message: 'Only creators can resume streams' });
    }

    const stream = await Stream.findById(req.params.streamId);

    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }

    if (stream.creator.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not authorized to resume this stream' });
    }

    if (stream.isLive) {
      return res.status(400).json({ message: 'Stream is already live' });
    }

    stream.isLive = true;
    stream.endedAt = undefined;
    await stream.save();
    await stream.populate('creator', 'username');

    res.json({
      message: 'Stream resumed successfully',
      stream: {
        id: stream._id,
        streamCode: stream.streamCode,
        title: stream.title,
        description: stream.description,
        creator: {
          id: stream.creator._id,
          username: stream.creator.username,
        },
        viewers: stream.viewers.length,
        likes: stream.likes.length,
        isLive: stream.isLive,
        createdAt: stream.createdAt,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/chat/:streamId', async (req, res) => {
  try {
    const stream = await Stream.findById(req.params.streamId)
      .select('chatMessages');

    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }

    res.json({
      messages: stream.chatMessages.map(msg => ({
        userId: msg.userId.toString(),
        username: msg.username,
        message: msg.message,
        timestamp: msg.timestamp,
      })),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/my-streams', auth, async (req, res) => {
  try {
    if (req.user.userType !== 'creator') {
      return res.status(403).json({ message: 'Only creators can view their streams' });
    }

    const streams = await Stream.find({ creator: req.user._id })
      .sort({ createdAt: -1 });

    res.json({
      streams: streams.map(stream => ({
        id: stream._id,
        streamCode: stream.streamCode,
        title: stream.title,
        description: stream.description,
        isLive: stream.isLive,
        viewers: stream.viewers.length,
        likes: stream.likes.length,
        createdAt: stream.createdAt,
        endedAt: stream.endedAt,
      })),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;

