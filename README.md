# Stok — Native Chat Application

A full-featured, cross-platform chat application with AI agent support.

## Features

| Feature | Status |
|---------|--------|
| Phone + OTP login | ✅ |
| Direct messages | ✅ |
| Online/Offline presence | ✅ |
| Voice recording | ✅ |
| AI prompt widgets | ✅ |
| Video & voice calls (WebRTC) | ✅ |
| Public channels & broadcasts | ✅ |
| Event scheduling | ✅ |
| AI Agents (Claude-powered) | ✅ |
| Group chats | ✅ |
| Message replies | ✅ |
| Read receipts & typing indicators | ✅ |
| Native SMS reading (Android) | ✅ |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (iOS, Android, Web, macOS, Windows, Linux) |
| Backend | Node.js + Express + TypeScript |
| Database | PostgreSQL (Prisma ORM) |
| Real-time | Socket.io |
| Video/Voice | WebRTC (flutter_webrtc) |
| AI Agents | Anthropic Claude API |
| Auth | Phone OTP + JWT |
| Cache | Redis |

## Project Structure

```
stok/
├── backend/           # Node.js + Express API
│   ├── src/
│   │   ├── routes/    # Auth, Users, Conversations, Groups, Channels, Events, Agents, Calls
│   │   ├── socket/    # Chat, Presence, Video signaling handlers
│   │   ├── services/  # OTP, AI (Anthropic), Notifications
│   │   └── middleware/# JWT auth
│   └── prisma/        # PostgreSQL schema + migrations
├── frontend/          # Flutter cross-platform app
│   └── lib/
│       ├── screens/   # Auth, Home, Chat, Groups, Channels, Events, Calls, Settings
│       ├── widgets/   # MessageBubble, VoiceRecorder, UserAvatar, etc.
│       ├── providers/ # Auth, Chat, Presence, Call
│       ├── services/  # API, Socket, WebRTC, Auth
│       └── models/    # User, Message, Conversation, Group, Channel, Event
└── docker-compose.yml
```

## Quick Start

### Prerequisites
- Node.js 20+
- Flutter 3.2+
- Docker & Docker Compose
- PostgreSQL (or use Docker)

### 1. Clone & Setup Environment

```bash
cd stok/backend
cp .env.example .env
# Edit .env and set your ANTHROPIC_API_KEY
```

### 2. Start Database with Docker

```bash
# From stok/ root
docker-compose up postgres redis -d
```

### 3. Backend Setup

```bash
cd backend
npm install
npx prisma migrate dev --name init
npx prisma generate
npm run dev
```

Backend runs on **http://localhost:3000**

### 4. Frontend Setup

```bash
cd frontend
flutter pub get
flutter run   # for connected device/emulator
# Or:
flutter run -d chrome  # for web
flutter run -d macos   # for macOS
```

### 5. Configure Frontend

Edit `frontend/lib/config/app_config.dart`:
```dart
static const String baseUrl = 'http://YOUR_MACHINE_IP:3000';
```
Use your machine's local IP (not `localhost`) when testing on a physical device.

## Development OTP

In development mode (`DEV_OTP_BYPASS=true` in `.env`), any phone number accepts OTP **`123456`**.

## AI Agents

1. Go to **Settings → AI Agents**
2. Tap **New Agent**
3. Set name, description, Claude model, and system prompt
4. The agent appears as a contact — start a chat with it
5. All messages are automatically forwarded to Claude and responded to in real-time

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/send-otp` | Send OTP to phone |
| POST | `/api/auth/verify-otp` | Verify OTP, get JWT |
| GET | `/api/users/me` | Get current user |
| GET | `/api/users/search?q=` | Search users |
| GET/POST | `/api/conversations` | List / start conversation |
| GET/POST | `/api/conversations/:id/messages` | Get / send messages |
| GET/POST | `/api/groups` | List / create groups |
| POST | `/api/groups/:id/messages` | Send group message |
| GET/POST | `/api/channels` | Discover / create channels |
| POST | `/api/channels/:id/join` | Join channel |
| POST | `/api/channels/:id/broadcast` | Broadcast to channel (admin) |
| GET/POST | `/api/events` | List / create events |
| PATCH | `/api/events/:id/rsvp` | RSVP to event |
| GET/POST | `/api/agents` | List / create AI agents |
| POST | `/api/agents/:id/chat` | Chat with agent (REST) |
| POST | `/api/calls/initiate` | Start a call |

## WebSocket Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `send_message` | Client→Server | Send DM |
| `new_message` | Server→Client | Receive DM |
| `send_group_message` | Client→Server | Send group message |
| `new_group_message` | Server→Client | Receive group message |
| `user_typing` / `user_stopped_typing` | Both | Typing indicators |
| `user_status` | Server→Client | Online/offline updates |
| `new_broadcast` | Server→Client | Channel broadcast |
| `event_invite` | Server→Client | Event invitation |
| `incoming_call` | Server→Client | Incoming call notification |
| `webrtc_offer/answer/ice_candidate` | Both | WebRTC signaling |

## Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Full support (SMS reading, calls, notifications) |
| iOS | ✅ Full support (calls, notifications) |
| Web | ✅ Core features |
| macOS | ✅ Core features |
| Windows | ✅ Core features |
| Linux | ✅ Core features |

## Environment Variables

```env
DATABASE_URL=postgresql://user:pass@localhost:5432/stok_db
REDIS_URL=redis://localhost:6379
JWT_SECRET=your_secret_key
PORT=3000
ANTHROPIC_API_KEY=your_key   # For AI agents
DEV_OTP_BYPASS=true           # Use 123456 as OTP in dev
TWILIO_ACCOUNT_SID=           # Optional: real SMS OTP
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
```
