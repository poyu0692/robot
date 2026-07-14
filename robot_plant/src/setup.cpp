#include "setup.h"
#include <Arduino.h>
#include <WiFiS3.h>
#include "const.h"
#include "network.h"
#include "status_display.h"

namespace Setup {
    void setupMotor();
    void setupSonar();
    void setupNetwork();

    void setup() {
        Serial.begin(115200);
        setupMotor();
        setupSonar();
        StatusDisplay::begin();
        setupNetwork();
    }

    void setupMotor() {
        pinMode(Pin::LEFT_MOTOR_FWD, OUTPUT);
        pinMode(Pin::LEFT_MOTOR_REV, OUTPUT);
        pinMode(Pin::RIGHT_MOTOR_FWD, OUTPUT);
        pinMode(Pin::RIGHT_MOTOR_REV, OUTPUT);
        Serial.println("[Info] Motor setup done.");
    }

    void setupSonar() {
        pinMode(Pin::SONAR_TRIG, OUTPUT);
        pinMode(Pin::SONAR_ECHO, INPUT);
        Serial.println("[Info] Sonar setup done.");
    }

    void setupNetwork() {
        // Check WiFi module
        if (WiFi.status() == WL_NO_MODULE) {
            Serial.println("[Error] Communication with WiFi module failed!");
            return;
        }

        // Check WiFi firmware version
        String fv = WiFi.firmwareVersion();
        if (fv < WIFI_FIRMWARE_LATEST_VERSION) {
            Serial.println("[Warning] The firmware version was old. Please upgrade.");
        }

        // Connection attempts are handled from loop() so that status display and
        // the rest of the robot remain responsive while Wi-Fi is unavailable.
        Serial.println("[Info] Network setup done. Connecting...");
    }
} // namespace Setup
