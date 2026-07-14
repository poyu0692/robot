#include "network.h"
#include <Arduino.h>
#include <WiFiS3.h>
#include "const.h"

namespace Network {
    WiFiUDP udp;

    namespace {
        IPAddress controllerIp;
        uint16_t controllerPort = 0;
        bool hasController = false;
        bool hasReconnectAttempt = false;
        unsigned long lastReconnectAttemptMs = 0;
        unsigned long lastControllerPacketMs = 0;
        bool udpStarted = false;
    } // namespace

    bool begin() {
        udp.stop();
        udpStarted = udp.begin(LOCAL_PORT) == 1;
        return udpStarted;
    }

    void maintainConnection() {
        if (WiFi.status() == WL_NO_MODULE) {
            udp.stop();
            udpStarted = false;
            hasController = false;
            return;
        }

        if (WiFi.status() == WL_CONNECTED) {
            hasReconnectAttempt = false;
            if (!udpStarted) {
                if (begin()) {
                    Serial.println("[Info] WiFi connected. UDP started.");
                }
            }

            return;
        }

        udpStarted = false;
        hasController = false;
        const unsigned long now = millis();
        if (hasReconnectAttempt && now - lastReconnectAttemptMs < RECONNECT_INTERVAL_MS) {
            return;
        }

        hasReconnectAttempt = true;
        lastReconnectAttemptMs = now;
        Serial.println("[Info] WiFi disconnected. reconnecting...");
        WiFi.begin(SSID, PASSWORD);
    }

    Status status() {
        if (WiFi.status() == WL_NO_MODULE) {
            return Status::NoModule;
        }

        if (WiFi.status() != WL_CONNECTED || !udpStarted) {
            return Status::Connecting;
        }

        const unsigned long now = millis();
        if (hasController && now - lastControllerPacketMs <= CONTROLLER_TIMEOUT_MS) {
            return Status::ControllerActive;
        }
        return Status::WiFiConnected;
    }

    bool receiveMotorPacket(int32_t buf[2]) {
        constexpr size_t packetSize = sizeof(int32_t) * 2;

        if (!udpStarted) {
            return false;
        }

        if (udp.parsePacket() != packetSize) {
            return false;
        }

        bool received = udp.read(
            reinterpret_cast<uint8_t*>(buf),
            packetSize
        ) == packetSize;

        if (received) {
            controllerIp = udp.remoteIP();
            controllerPort = udp.remotePort();
            hasController = true;
            lastControllerPacketMs = millis();
        }

        return received;
    }

    bool sendDistance(float distanceM) {
        if (!hasController) {
            return false;
        }

        if (!udp.beginPacket(controllerIp, controllerPort)) {
            return false;
        }

        udp.write(
            reinterpret_cast<const uint8_t*>(&distanceM),
            sizeof(distanceM)
        );

        return udp.endPacket() == 1;
    }
} // namespace Network
