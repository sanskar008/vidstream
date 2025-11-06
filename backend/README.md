# VidStream Backend

Node.js backend for VidStream video streaming application.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file in the backend directory with the following variables:
```
PORT=5000
MONGODB_URI=your_mongodb_atlas_connection_string
JWT_SECRET=your_jwt_secret_key_here
NODE_ENV=development
```

3. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user/creator
- `POST /api/auth/login` - Login user/creator
- `GET /api/auth/me` - Get current user (requires auth)

### Streams
- `POST /api/streams/create` - Create a new stream (creator only)
- `GET /api/streams/live` - Get all live streams
- `GET /api/streams/code/:streamCode` - Get stream by code
- `POST /api/streams/join/:streamId` - Join a stream
- `POST /api/streams/end/:streamId` - End a stream (creator only)
- `GET /api/streams/my-streams` - Get creator's streams

### Profiles
- `GET /api/profiles/:userId` - Get user profile
- `POST /api/profiles/follow/:userId` - Follow a creator
- `POST /api/profiles/unfollow/:userId` - Unfollow a creator
- `GET /api/profiles/followers/list` - Get followers list (creator only)

