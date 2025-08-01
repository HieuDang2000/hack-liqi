#!/usr/bin/env python3
import asyncio
import websockets
import json
import logging
from datetime import datetime
import threading
import time
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global variables
connected_clients = set()
game_data = {}
game_data_lock = threading.Lock()

# Server configuration
HOST = "0.0.0.0"  # Listen on all interfaces
GAME_PORT = 8080  # Port for game client connections
WEB_PORT = 8081   # Port for web client connections
DOMAIN = "map.meonohehe.men"

class GameDataManager:
    def __init__(self):
        self.data = {}
        self.lock = threading.Lock()
    
    def update_data(self, new_data):
        with self.lock:
            self.data = new_data
            self.data['last_update'] = datetime.now().isoformat()
    
    def get_data(self):
        with self.lock:
            return self.data.copy()

game_manager = GameDataManager()

async def handle_game_client(websocket, path):
    """Handle connection from the hack (game client)"""
    client_ip = websocket.remote_address[0]
    logger.info(f"Game client connected from {client_ip}")
    
    try:
        async for message in websocket:
            try:
                # Parse WebSocket frame
                if len(message) < 2:
                    continue
                
                # Simple WebSocket frame parsing
                payload_length = message[1] & 0x7F
                if payload_length < 126:
                    payload_start = 2
                else:
                    payload_start = 4
                
                payload = message[payload_start:payload_start + payload_length]
                data = json.loads(payload.decode('utf-8'))
                
                # Update game data
                game_manager.update_data(data)
                logger.info(f"Received game data from {client_ip}: {len(data.get('enemies', []))} enemies")
                
            except json.JSONDecodeError as e:
                logger.error(f"JSON decode error from {client_ip}: {e}")
            except Exception as e:
                logger.error(f"Error processing message from {client_ip}: {e}")
                
    except websockets.exceptions.ConnectionClosed:
        logger.info(f"Game client {client_ip} disconnected")
    except Exception as e:
        logger.error(f"Game client {client_ip} error: {e}")

async def handle_web_client(websocket, path):
    """Handle connection from web browser"""
    client_ip = websocket.remote_address[0]
    logger.info(f"Web client connected from {client_ip}")
    connected_clients.add(websocket)
    
    try:
        # Send initial data
        initial_data = game_manager.get_data()
        if initial_data:
            await websocket.send(json.dumps(initial_data))
        
        # Keep connection alive and send updates
        while True:
            await asyncio.sleep(0.1)  # 10 FPS update rate
            
            current_data = game_manager.get_data()
            if current_data and current_data != initial_data:
                await websocket.send(json.dumps(current_data))
                initial_data = current_data
                
    except websockets.exceptions.ConnectionClosed:
        logger.info(f"Web client {client_ip} disconnected")
    except Exception as e:
        logger.error(f"Web client {client_ip} error: {e}")
    finally:
        connected_clients.discard(websocket)

async def main():
    # Start WebSocket server for game clients
    game_server = await websockets.serve(
        handle_game_client, 
        HOST, 
        GAME_PORT,
        subprotocols=["websocket"]
    )
    
    # Start WebSocket server for web clients
    web_server = await websockets.serve(
        handle_web_client,
        HOST,
        WEB_PORT,
        subprotocols=["websocket"]
    )
    
    logger.info("=" * 50)
    logger.info("AOV External Map Server Started")
    logger.info("=" * 50)
    logger.info(f"Domain: {DOMAIN}")
    logger.info(f"Game client server: ws://{DOMAIN}:{GAME_PORT}")
    logger.info(f"Web client server: ws://{DOMAIN}:{WEB_PORT}")
    logger.info(f"Local game client: ws://localhost:{GAME_PORT}")
    logger.info(f"Local web client: ws://localhost:{WEB_PORT}")
    logger.info("=" * 50)
    
    await asyncio.gather(
        game_server.wait_closed(),
        web_server.wait_closed()
    )

if __name__ == "__main__":
    asyncio.run(main()) 