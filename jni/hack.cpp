#include "hack.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netdb.h>
#include <thread>
#include <sstream>
#include <iomanip>

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
    
    std::ostringstream json;
    json << std::fixed << std::setprecision(2);
    
    json << "{";
    json << "\"type\":\"game_data\",";
    json << "\"timestamp\":" << (unsigned long long)time(NULL) << ",";
    
    // My position
    json << "\"my_data\":{";
    json << "\"position\":{";
    json << "\"x\":" << currentGameData.myPosition.x << ",";
    json << "\"y\":" << currentGameData.myPosition.y << ",";
    json << "\"z\":" << currentGameData.myPosition.z;
    json << "},";
    json << "\"camp\":" << currentGameData.myCamp;
    json << "},";
    
    // Enemies data
    json << "\"enemies\":[";
    for (size_t i = 0; i < currentGameData.enemyPositions.size(); i++) {
        if (i > 0) json << ",";
        json << "{";
        json << "\"position\":{";
        json << "\"x\":" << currentGameData.enemyPositions[i].x << ",";
        json << "\"y\":" << currentGameData.enemyPositions[i].y << ",";
        json << "\"z\":" << currentGameData.enemyPositions[i].z;
        json << "},";
        json << "\"camp\":" << currentGameData.enemyCamps[i] << ",";
        json << "\"hp\":" << currentGameData.enemyHPs[i] << ",";
        json << "\"max_hp\":" << currentGameData.enemyMaxHPs[i] << ",";
        json << "\"name\":\"" << currentGameData.enemyNames[i] << "\"";
        json << "}";
    }
    json << "]";
    json << "}";
    
    std::string json_str = json.str();
    
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
