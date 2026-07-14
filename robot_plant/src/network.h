#pragma once

#include <stdint.h>
#include <WiFiUdp.h>

namespace Network {
    // Status used by the main loop and the status display.
    enum class Status {
        NoModule,
        Connecting,
        WiFiConnected,
        ControllerActive,
    };

    extern WiFiUDP udp;

    // Opens the local UDP port. Call after Wi-Fi connects.
    bool begin();
    // Maintains the Wi-Fi/UDP connection.
    void maintainConnection();
    // Returns the current connection and controller status.
    Status status();
    bool receiveMotorPacket(int32_t buf[2]);
    // Distance is sent as an IEEE 754 float in metres; a negative value means no echo.
    bool sendDistance(float distanceM);
} // namespace Network
