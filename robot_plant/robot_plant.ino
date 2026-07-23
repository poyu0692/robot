#include "lib.h"

int32_t buf[2]; // buf[0]: left, buf[1]: right
float distanceM;

void setup() {
    Setup::setup();
}

void loop() {
    Network::maintainConnection();

    if (Network::receiveMotorSpeedPacket(buf)) {
        Motor::setSpeed(buf[0], buf[1]);
        Motor::printSpeed(buf[0], buf[1]);
    }

    const Network::Status networkStatus = Network::status();
    const bool isControllerActive = networkStatus == Network::Status::ControllerActive;
    if (!isControllerActive) {
        Motor::setSpeed(0, 0);
    }

    if (Sonar::poll(distanceM) && isControllerActive) {
        Network::sendDistance(distanceM);
    }

    Motor::drive();
    // StatusDisplay::update(networkStatus);
    delay(0.01);
}
