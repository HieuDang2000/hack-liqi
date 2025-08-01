#include "hack.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <thread>
#include <json/json.h>

// WebSocket connection
int ws_socket = -1;
bool ws_connected = false;
std::thread ws_thread;

// Server configuration
const char* SERVER_DOMAIN = "map.meonohehe.men";
const int SERVER_PORT = 8080;

// Game data structure
struct GameData {
    Vector3 myPosition;
    int myCamp;
    std::vector<Vector3> enemyPositions;
    std::vector<int> enemyCamps;
    std::vector<int> enemyHPs;
    std::vector<int> enemyMaxHPs;
    std::vector<std::string> enemyNames;
};

GameData currentGameData;

// WebSocket functions
bool connectWebSocket() {
    ws_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (ws_socket < 0) return false;
    
    struct sockaddr_in server_addr;
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SERVER_PORT);
    
    // Resolve domain name to IP address
    struct hostent *he = gethostbyname(SERVER_DOMAIN);
    if (he == NULL) {
        close(ws_socket);
        return false;
    }
    
    server_addr.sin_addr = *((struct in_addr *)he->h_addr);
    
    if (connect(ws_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        close(ws_socket);
        return false;
    }
    
    // WebSocket handshake
    const char* handshake = "GET /ws HTTP/1.1\r\n"
                           "Host: map.meonohehe.men:8080\r\n"
                           "Upgrade: websocket\r\n"
                           "Connection: Upgrade\r\n"
                           "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
                           "Sec-WebSocket-Version: 13\r\n\r\n";
    
    send(ws_socket, handshake, strlen(handshake), 0);
    
    char response[1024];
    recv(ws_socket, response, sizeof(response), 0);
    
    ws_connected = true;
    return true;
}

void sendGameData() {
    if (!ws_connected) return;
    
    Json::Value root;
    root["type"] = "game_data";
    root["timestamp"] = (Json::Value::UInt64)time(NULL);
    
    // My position
    Json::Value myData;
    myData["position"]["x"] = currentGameData.myPosition.x;
    myData["position"]["y"] = currentGameData.myPosition.y;
    myData["position"]["z"] = currentGameData.myPosition.z;
    myData["camp"] = currentGameData.myCamp;
    root["my_data"] = myData;
    
    // Enemies data
    Json::Value enemies = Json::Value(Json::arrayValue);
    for (size_t i = 0; i < currentGameData.enemyPositions.size(); i++) {
        Json::Value enemy;
        enemy["position"]["x"] = currentGameData.enemyPositions[i].x;
        enemy["position"]["y"] = currentGameData.enemyPositions[i].y;
        enemy["position"]["z"] = currentGameData.enemyPositions[i].z;
        enemy["camp"] = currentGameData.enemyCamps[i];
        enemy["hp"] = currentGameData.enemyHPs[i];
        enemy["max_hp"] = currentGameData.enemyMaxHPs[i];
        enemy["name"] = currentGameData.enemyNames[i];
        enemies.append(enemy);
    }
    root["enemies"] = enemies;
    
    Json::FastWriter writer;
    std::string json_str = writer.write(root);
    
    // WebSocket frame
    std::string frame;
    frame.push_back(0x81); // FIN + text frame
    frame.push_back(json_str.length()); // Payload length
    frame += json_str;
    
    send(ws_socket, frame.c_str(), frame.length(), 0);
}

void dataCollectionThread() {
    while (ws_connected) {
        // Collect game data
        currentGameData.enemyPositions.clear();
        currentGameData.enemyCamps.clear();
        currentGameData.enemyHPs.clear();
        currentGameData.enemyMaxHPs.clear();
        currentGameData.enemyNames.clear();
        
        ActorManager *actorManager = KyriosFramework::get_actorManager();
        if (actorManager != nullptr) {
            List<ActorLinker *> *allHeros = actorManager->GetAllHeros();
            if (allHeros != nullptr) {
                ActorLinker **actorLinkers = (ActorLinker **)allHeros->getItems();
                
                for (int i = 0; i < allHeros->getSize(); i++) {
                    ActorLinker *actorLinker = actorLinkers[(i * 2) + 1];
                    if (actorLinker == nullptr) continue;
                    
                    if (actorLinker->IsHostPlayer()) {
                        // My data
                        currentGameData.myPosition = actorLinker->get_position();
                        currentGameData.myCamp = actorLinker->get_objCamp();
                    } else if (!actorLinker->IsHostCamp() && actorLinker->get_bVisible() && 
                               actorLinker->ValueComponent()->get_actorHp() > 0) {
                        // Enemy data
                        currentGameData.enemyPositions.push_back(actorLinker->get_position());
                        currentGameData.enemyCamps.push_back(actorLinker->get_objCamp());
                        currentGameData.enemyHPs.push_back(actorLinker->ValueComponent()->get_actorHp());
                        currentGameData.enemyMaxHPs.push_back(actorLinker->ValueComponent()->get_actorHpTotal());
                        
                        // Get enemy name if possible
                        CActorInfo *actorInfo = (CActorInfo*)actorLinker->ObjLinker();
                        if (actorInfo != nullptr) {
                            string *name = actorInfo->ActorName();
                            currentGameData.enemyNames.push_back(name ? name->c_str() : "Unknown");
                        } else {
                            currentGameData.enemyNames.push_back("Unknown");
                        }
                    }
                }
            }
        }
        
        // Send data to WebSocket
        sendGameData();
        
        // Sleep for 100ms (10 FPS update rate)
        usleep(100000);
    }
}

void hack_prepare(const char *_game_data_dir) {
    while (!il2cppMap) {
        il2cppMap = Tools::GetBaseAddress(TargetLibName);
        sleep(2);
    }
    
    Il2Cpp::Il2CppAttach();
    gameObject = new GameObject();
    
    // Connect to WebSocket server
    if (connectWebSocket()) {
        // Start data collection thread
        ws_thread = std::thread(dataCollectionThread);
        ws_thread.detach();
    }
}
