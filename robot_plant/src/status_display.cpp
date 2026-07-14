#include "status_display.h"

#include <Arduino.h>
#include <Arduino_LED_Matrix.h>

namespace StatusDisplay {
    namespace {
        constexpr uint8_t ROWS = 8;
        constexpr uint8_t COLUMNS = 12;
        constexpr unsigned long ERROR_BLINK_MS = 250;
        constexpr unsigned long CONNECTING_STEP_MS = 180;
        constexpr unsigned long WAITING_BLINK_MS = 800;

        ArduinoLEDMatrix matrix;
        Network::Status lastStatus = Network::Status::NoModule;
        unsigned long lastFrameKey = ~0UL;

        void clear(uint8_t frame[ROWS][COLUMNS]) {
            for (uint8_t row = 0; row < ROWS; ++row) {
                for (uint8_t column = 0; column < COLUMNS; ++column) {
                    frame[row][column] = 0;
                }
            }
        }

        void drawNoModule(uint8_t frame[ROWS][COLUMNS]) {
            for (uint8_t i = 0; i < ROWS; ++i) {
                frame[i][2 + i] = 1;
                frame[i][9 - i] = 1;
            }
        }

        void drawConnecting(uint8_t frame[ROWS][COLUMNS], uint8_t offset) {
            for (uint8_t i = 0; i < 3; ++i) {
                frame[4][(offset + i * 3) % COLUMNS] = 1;
            }
        }

        void drawWaiting(uint8_t frame[ROWS][COLUMNS]) {
            // Wi-Fi-style arcs centered on the matrix.
            frame[1][2] = frame[1][9] = 1;
            frame[2][3] = frame[2][8] = 1;
            frame[3][4] = frame[3][7] = 1;
            frame[4][5] = frame[4][6] = 1;
            frame[6][5] = frame[6][6] = 1;
        }

        void drawActive(uint8_t frame[ROWS][COLUMNS]) {
            // Check mark.
            frame[4][2] = 1;
            frame[5][3] = 1;
            frame[6][4] = 1;
            frame[5][5] = 1;
            frame[4][6] = 1;
            frame[3][7] = 1;
            frame[2][8] = 1;
            frame[1][9] = 1;
        }
    } // namespace

    void begin() {
        matrix.begin();
    }

    void update(Network::Status status) {
        const unsigned long now = millis();
        unsigned long frameKey = 0;

        switch (status) {
            case Network::Status::NoModule:
                frameKey = now / ERROR_BLINK_MS;
                break;
            case Network::Status::Connecting:
                frameKey = now / CONNECTING_STEP_MS;
                break;
            case Network::Status::WiFiConnected:
                frameKey = now / WAITING_BLINK_MS;
                break;
            case Network::Status::ControllerActive:
                break;
        }

        if (status == lastStatus && frameKey == lastFrameKey) {
            return;
        }

        uint8_t frame[ROWS][COLUMNS];
        clear(frame);

        switch (status) {
            case Network::Status::NoModule:
                if ((frameKey % 2) == 0) {
                    drawNoModule(frame);
                }
                break;
            case Network::Status::Connecting:
                drawConnecting(frame, frameKey % COLUMNS);
                break;
            case Network::Status::WiFiConnected:
                if ((frameKey % 2) == 0) {
                    drawWaiting(frame);
                }
                break;
            case Network::Status::ControllerActive:
                drawActive(frame);
                break;
        }

        matrix.renderBitmap(frame, ROWS, COLUMNS);
        lastStatus = status;
        lastFrameKey = frameKey;
    }
} // namespace StatusDisplay
