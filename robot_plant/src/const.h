#pragma once

namespace Pin {
    constexpr int LEFT_MOTOR_FWD = 9;
    constexpr int LEFT_MOTOR_REV = 6;
    constexpr int RIGHT_MOTOR_FWD = 5;
    constexpr int RIGHT_MOTOR_REV = 10;
    constexpr int SONAR_TRIG = 3;
    constexpr int SONAR_ECHO = 2;
} // namespace Pin

// Network
constexpr char SSID[] = "";
constexpr char PASSWORD[] = "";
constexpr unsigned int LOCAL_PORT = 1240;
constexpr unsigned long RECONNECT_INTERVAL_MS = 5000;
constexpr unsigned long CONTROLLER_TIMEOUT_MS = 1000;

// Sonar
constexpr unsigned long SONAR_TRIGGER_INTERVAL_US = 60000;
constexpr unsigned long SONAR_ECHO_TIMEOUT_US = 30000;
constexpr float SONAR_TEMPERATURE_C = 20.0f;
