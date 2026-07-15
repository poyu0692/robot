#include "status_display.h"

#include <Arduino.h>
#include <Arduino_LED_Matrix.h>

namespace StatusDisplay {
    namespace {
        constexpr uint8_t ROWS = 8;
        constexpr uint8_t COLUMNS = 12;
        constexpr unsigned long CONNECTING_STEP_MS = 180;

        constexpr uint8_t DIGIT_PATTERNS[10][5] = {
            {0b111, 0b101, 0b101, 0b101, 0b111}, // 0
            {0b010, 0b110, 0b010, 0b010, 0b111}, // 1
            {0b111, 0b001, 0b111, 0b100, 0b111}, // 2
            {0b111, 0b001, 0b111, 0b001, 0b111}, // 3
            {0b101, 0b101, 0b111, 0b001, 0b001}, // 4
            {0b111, 0b100, 0b111, 0b001, 0b111}, // 5
            {0b111, 0b100, 0b111, 0b101, 0b111}, // 6
            {0b111, 0b001, 0b010, 0b010, 0b010}, // 7
            {0b111, 0b101, 0b111, 0b101, 0b111}, // 8
            {0b111, 0b101, 0b111, 0b001, 0b111}, // 9
        };

        ArduinoLEDMatrix matrix;
        bool initialized = false;
        Network::Status lastStatus = Network::Status::NoModule;
        unsigned long lastFrameKey = ~0UL;

        void clear(uint8_t frame[ROWS][COLUMNS]) {
            for (uint8_t row = 0; row < ROWS; ++row) {
                for (uint8_t column = 0; column < COLUMNS; ++column) {
                    frame[row][column] = 0;
                }
            }
        }

        void drawErrorCode(uint8_t frame[ROWS][COLUMNS], uint8_t code) {
            code %= 10;

            // Exclamation mark.
            for (uint8_t row = 1; row <= 4; ++row) {
                frame[row][3] = 1;
            }
            frame[6][3] = 1;

            // 3x5 diagnostic digit.
            for (uint8_t row = 0; row < 5; ++row) {
                const uint8_t bits = DIGIT_PATTERNS[code][row];
                for (uint8_t column = 0; column < 3; ++column) {
                    frame[row + 1][6 + column] =
                        (bits >> (2 - column)) & 0x01;
                }
            }
        }

        void drawConnecting(uint8_t frame[ROWS][COLUMNS], uint8_t offset) {
            for (uint8_t i = 0; i < 3; ++i) {
                frame[4][(offset + i * 3) % COLUMNS] = 1;
            }
        }

        void drawControllerTimedOut(uint8_t frame[ROWS][COLUMNS]) {
            // Pause symbol (II), centered on the matrix.
            for (uint8_t row = 1; row <= 6; ++row) {
                frame[row][3] = frame[row][4] = 1;
                frame[row][7] = frame[row][8] = 1;
            }
        }

        void drawWaitingForController(uint8_t frame[ROWS][COLUMNS]) {
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

        void drawControllerActive(uint8_t frame[ROWS][COLUMNS]) {
            // Circle, indicating an active controller connection.
            frame[0][5] = frame[0][6] = 1;
            frame[1][4] = frame[1][7] = 1;
            for (uint8_t row = 2; row <= 5; ++row) {
                frame[row][3] = frame[row][8] = 1;
            }
            frame[6][4] = frame[6][7] = 1;
            frame[7][5] = frame[7][6] = 1;
        }
    } // namespace

    void update(Network::Status status) {
        if (!initialized) {
            matrix.begin();
            initialized = true;
        }

        const unsigned long now = millis();
        unsigned long frameKey = 0;

        switch (status) {
            case Network::Status::WiFiConnecting:
                frameKey = now / CONNECTING_STEP_MS;
                break;
            case Network::Status::NoModule:
            case Network::Status::SsidNotFound:
            case Network::Status::WiFiConnectFailed:
            case Network::Status::WiFiConnectionLost:
            case Network::Status::UdpStartFailed:
            case Network::Status::UnknownError:
            case Network::Status::WaitingForController:
            case Network::Status::ControllerActive:
            case Network::Status::ControllerTimedOut:
                break;
        }

        if (status == lastStatus && frameKey == lastFrameKey) {
            return;
        }

        uint8_t frame[ROWS][COLUMNS];
        clear(frame);

        switch (status) {
            case Network::Status::NoModule:
                drawErrorCode(frame, 1);
                break;
            case Network::Status::WiFiConnecting:
                drawConnecting(frame, frameKey % COLUMNS);
                break;
            case Network::Status::SsidNotFound:
                drawErrorCode(frame, 2);
                break;
            case Network::Status::WiFiConnectFailed:
                drawErrorCode(frame, 3);
                break;
            case Network::Status::WiFiConnectionLost:
                drawErrorCode(frame, 4);
                break;
            case Network::Status::UdpStartFailed:
                drawErrorCode(frame, 5);
                break;
            case Network::Status::WaitingForController:
                drawWaitingForController(frame);
                break;
            case Network::Status::ControllerActive:
                drawControllerActive(frame);
                break;
            case Network::Status::ControllerTimedOut:
                drawControllerTimedOut(frame);
                break;
            case Network::Status::UnknownError:
                drawErrorCode(frame, 9);
                break;
        }

        matrix.renderBitmap(frame, ROWS, COLUMNS);
        lastStatus = status;
        lastFrameKey = frameKey;
    }
} // namespace StatusDisplay
