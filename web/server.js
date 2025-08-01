const WebSocket = require('ws');
const express = require('express');
const cors = require('cors');
const path = require('path');

// Configuration
const HOST = '0.0.0.0';
const GAME_PORT = 8080;
const WEB_PORT = 8081;
const DOMAIN = 'map.meonohehe.men';

// Express app for serving static files
const app = express();
app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

// Serve index.html
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Start HTTP server
app.listen(WEB_PORT, HOST, () => {
    console.log(`[${new Date().toISOString()}] HTTP Server running on ${HOST}:${WEB_PORT}`);
    console.log(`[${new Date().toISOString()}] Domain: ${DOMAIN}`);
});

// WebSocket server for game data
const gameWss = new WebSocket.Server({ port: GAME_PORT });
console.log(`[${new Date().toISOString()}] Game WebSocket Server running on ${HOST}:${GAME_PORT}`);

// WebSocket server for web clients
const webWss = new WebSocket.Server({ port: WEB_PORT + 1 });
console.log(`[${new Date().toISOString()}] Web WebSocket Server running on ${HOST}:${WEB_PORT + 1}`);

// Store connected clients
let gameClients = new Set();
let webClients = new Set();

// Game WebSocket connections (from hack module)
gameWss.on('connection', (ws, req) => {
    const clientIP = req.socket.remoteAddress;
    console.log(`[${new Date().toISOString()}] Game client connected from ${clientIP}`);
    gameClients.add(ws);

    ws.on('message', (data) => {
        try {
            const message = data.toString();
            console.log(`[${new Date().toISOString()}] Received game data from ${clientIP}: ${message.substring(0, 100)}...`);
            
            // Broadcast to all web clients
            webClients.forEach((webClient) => {
                if (webClient.readyState === WebSocket.OPEN) {
                    webClient.send(message);
                }
            });
        } catch (error) {
            console.error(`[${new Date().toISOString()}] Error processing game data:`, error);
        }
    });

    ws.on('close', () => {
        console.log(`[${new Date().toISOString()}] Game client disconnected from ${clientIP}`);
        gameClients.delete(ws);
    });

    ws.on('error', (error) => {
        console.error(`[${new Date().toISOString()}] Game client error from ${clientIP}:`, error);
        gameClients.delete(ws);
    });
});

// Web WebSocket connections (from browser)
webWss.on('connection', (ws, req) => {
    const clientIP = req.socket.remoteAddress;
    console.log(`[${new Date().toISOString()}] Web client connected from ${clientIP}`);
    webClients.add(ws);

    // Send welcome message
    ws.send(JSON.stringify({
        type: 'welcome',
        message: 'Connected to AOV External Map System',
        timestamp: Date.now()
    }));

    ws.on('close', () => {
        console.log(`[${new Date().toISOString()}] Web client disconnected from ${clientIP}`);
        webClients.delete(ws);
    });

    ws.on('error', (error) => {
        console.error(`[${new Date().toISOString()}] Web client error from ${clientIP}:`, error);
        webClients.delete(ws);
    });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        gameClients: gameClients.size,
        webClients: webClients.size,
        domain: DOMAIN
    });
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n[${new Date().toISOString()}] Shutting down servers...');
    
    gameWss.close(() => {
        console.log('[${new Date().toISOString()}] Game WebSocket server closed');
    });
    
    webWss.close(() => {
        console.log('[${new Date().toISOString()}] Web WebSocket server closed');
    });
    
    process.exit(0);
});

console.log(`[${new Date().toISOString()}] AOV External Map System started successfully!`);
console.log(`[${new Date().toISOString()}] Game data port: ${GAME_PORT}`);
console.log(`[${new Date().toISOString()}] Web interface port: ${WEB_PORT}`);
console.log(`[${new Date().toISOString()}] WebSocket port: ${WEB_PORT + 1}`); 