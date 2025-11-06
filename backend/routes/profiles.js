const express = require('express');
const User = require('../models/User');
const Stream = require('../models/Stream');
const auth = require('../middleware/auth');

const router = express.Router();

router.get('/:userId', async (req, res) => {
  try {
    const user = await User.findById(req.params.userId)
      .select('-password')
      .populate('followers', 'username')
      .populate('following', 'username');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const liveStreams = await Stream.countDocuments({
      creator: user._id,
      isLive: true,
    });

    let isFollowing = false;
    if (req.query.currentUserId) {
      const currentUser = await User.findById(req.query.currentUserId);
      if (currentUser) {
        isFollowing = currentUser.following.some(
          id => id.toString() === user._id.toString()
        );
      }
    }

    res.json({
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        userType: user.userType,
        followers: user.followers.map(f => ({
          id: f._id,
          username: f.username,
        })),
        following: user.following.map(f => ({
          id: f._id,
          username: f.username,
        })),
        followersCount: user.followers.length,
        followingCount: user.following.length,
        liveStreams,
        isFollowing,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/follow/:userId', auth, async (req, res) => {
  try {
    if (req.user._id.toString() === req.params.userId) {
      return res.status(400).json({ message: 'Cannot follow yourself' });
    }

    const userToFollow = await User.findById(req.params.userId);

    if (!userToFollow) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (userToFollow.userType !== 'creator') {
      return res.status(400).json({ message: 'Can only follow creators' });
    }

    const currentUser = await User.findById(req.user._id);

    if (currentUser.following.includes(userToFollow._id)) {
      return res.status(400).json({ message: 'Already following this creator' });
    }

    currentUser.following.push(userToFollow._id);
    userToFollow.followers.push(currentUser._id);

    await currentUser.save();
    await userToFollow.save();

    res.json({ message: 'Successfully followed creator' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/unfollow/:userId', auth, async (req, res) => {
  try {
    const userToUnfollow = await User.findById(req.params.userId);

    if (!userToUnfollow) {
      return res.status(404).json({ message: 'User not found' });
    }

    const currentUser = await User.findById(req.user._id);

    if (!currentUser.following.includes(userToUnfollow._id)) {
      return res.status(400).json({ message: 'Not following this creator' });
    }

    currentUser.following = currentUser.following.filter(
      id => id.toString() !== userToUnfollow._id.toString()
    );
    userToUnfollow.followers = userToUnfollow.followers.filter(
      id => id.toString() !== currentUser._id.toString()
    );

    await currentUser.save();
    await userToUnfollow.save();

    res.json({ message: 'Successfully unfollowed creator' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/followers/list', auth, async (req, res) => {
  try {
    if (req.user.userType !== 'creator') {
      return res.status(403).json({ message: 'Only creators can view followers list' });
    }

    const user = await User.findById(req.user._id)
      .populate('followers', 'username email createdAt');

    res.json({
      followers: user.followers.map(f => ({
        id: f._id,
        username: f.username,
        email: f.email,
        createdAt: f.createdAt,
      })),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/search/:query', async (req, res) => {
  try {
    const query = req.params.query;
    
    if (!query || query.length < 2) {
      return res.status(400).json({ message: 'Search query must be at least 2 characters' });
    }

    const users = await User.find({
      userType: 'creator',
      $or: [
        { username: { $regex: query, $options: 'i' } },
        { email: { $regex: query, $options: 'i' } },
      ],
    })
      .select('-password')
      .limit(20);

    const liveStreamsPromises = users.map(user =>
      Stream.countDocuments({ creator: user._id, isLive: true })
    );
    const liveStreamsCounts = await Promise.all(liveStreamsPromises);

    res.json({
      creators: users.map((user, index) => ({
        id: user._id,
        username: user.username,
        email: user.email,
        followersCount: user.followers.length,
        liveStreams: liveStreamsCounts[index],
        createdAt: user.createdAt,
      })),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;

