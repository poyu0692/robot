#pragma once

#include <stdint.h>
#include <WiFiUdp.h>

namespace Network {
    // Status used by the main loop and the status display.
    enum class Status {
        NoModule,
        WiFiConnecting,
        SsidNotFound,
        WiFiConnectFailed,
        WiFiConnectionLost,
        UdpStartFailed,
        WaitingForController,
        ControllerActive,
        ControllerTimedOut,
        UnknownError,
    };

    extern WiFiUDP udp;

    bool begin();
    void maintainConnection();
    Status status();
    bool receiveMotorSpeedPacket(int32_t buf[2]);
    bool sendDistance(float distanceM);
} // namespace Network
