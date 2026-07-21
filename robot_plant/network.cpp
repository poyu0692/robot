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
        bool udpStartFailed = false;
        bool localIpReported = false;
        constexpr uint8_t MAX_MOTOR_PACKETS_PER_LOOP = 4;
        Status lastWiFiFailure = Status::WiFiConnecting;
    } // namespace

    bool begin() {
        udp.stop();
        udpStarted = udp.begin(LOCAL_PORT) == 1;
        udpStartFailed = !udpStarted;
        return udpStarted;
    }

    void maintainConnection() {
        const int wifiStatus = WiFi.status();

        if (wifiStatus == WL_NO_MODULE) {
            udp.stop();
            udpStarted = false;
            udpStartFailed = false;
            hasController = false;
            localIpReported = false;
            lastWiFiFailure = Status::WiFiConnecting;
            return;
        }

        switch (wifiStatus) {
            case WL_NO_SSID_AVAIL:
                lastWiFiFailure = Status::SsidNotFound;
                break;
            case WL_CONNECT_FAILED:
                lastWiFiFailure = Status::WiFiConnectFailed;
                break;
            case WL_CONNECTION_LOST:
                lastWiFiFailure = Status::WiFiConnectionLost;
                break;
            default:
                break;
        }

        if (wifiStatus == WL_CONNECTED) {
            hasReconnectAttempt = false;
            lastWiFiFailure = Status::WiFiConnecting;
            if (!udpStarted) {
                if (begin()) {
                    Serial.println("[Info] WiFi connected. UDP started.");
                }
            }

            const IPAddress localIp = WiFi.localIP();
            if (!localIpReported && localIp != IPAddress(0, 0, 0, 0)) {
                Serial.print("[Info] Local IP: ");
                Serial.println(localIp);
                localIpReported = true;
            }

            return;
        }

        udpStarted = false;
        udpStartFailed = false;
        hasController = false;
        localIpReported = false;
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
        const int wifiStatus = WiFi.status();

        switch (wifiStatus) {
            case WL_NO_MODULE:
                return Status::NoModule;
            case WL_NO_SSID_AVAIL:
                return Status::SsidNotFound;
            case WL_CONNECT_FAILED:
                return Status::WiFiConnectFailed;
            case WL_CONNECTION_LOST:
                return Status::WiFiConnectionLost;
            case WL_IDLE_STATUS:
            case WL_SCAN_COMPLETED:
            case WL_DISCONNECTED:
                break;
            case WL_CONNECTED:
                break;
            default:
                return Status::UnknownError;
        }

        if (wifiStatus != WL_CONNECTED &&
            lastWiFiFailure != Status::WiFiConnecting) {
            return lastWiFiFailure;
        }

        if (wifiStatus != WL_CONNECTED) {
            return Status::WiFiConnecting;
        }

        if (!udpStarted) {
            return udpStartFailed
                ? Status::UdpStartFailed
                : Status::WiFiConnecting;
        }

        const unsigned long now = millis();
        if (hasController && now - lastControllerPacketMs <= CONTROLLER_TIMEOUT_MS) {
            return Status::ControllerActive;
        }
        if (hasController) {
            return Status::ControllerTimedOut;
        }
        return Status::WaitingForController;
    }

    bool receiveMotorSpeedPacket(int32_t buf[2]) {
        constexpr size_t packetSize = sizeof(int32_t) * 2;

        if (!udpStarted) {
            return false;
        }

        // Motor input is state, so prefer the newest valid packet. The bound
        // prevents a continuous packet stream from starving the main loop.
        bool received = false;
        for (uint8_t i = 0; i < MAX_MOTOR_PACKETS_PER_LOOP; ++i) {
            const int packetLength = udp.parsePacket();
            if (packetLength <= 0) {
                break;
            }

            if (packetLength != packetSize) {
                udp.flush();
                continue;
            }

            int32_t latest[2];
            const IPAddress senderIp = udp.remoteIP();
            const uint16_t senderPort = udp.remotePort();
            const bool valid = udp.read(
                reinterpret_cast<uint8_t*>(latest),
                packetSize
            ) == packetSize;
            udp.flush();

            if (valid) {
                buf[0] = latest[0];
                buf[1] = latest[1];
                controllerIp = senderIp;
                controllerPort = senderPort;
                hasController = true;
                lastControllerPacketMs = millis();
                received = true;
            }
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
