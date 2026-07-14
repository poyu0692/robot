#include "src/lib.h"

int32_t buf[2]; // buf[0]: left, buf[1]: right
float distanceM;

void setup() {
    Setup::setup();
}

void loop() {
    Network::maintainConnection();

    if (Network::receiveMotorPacket(buf)) {
        Motor::setSpeed(buf[0], buf[1]);
        Motor::printSpeed(buf[0], buf[1]);
    }

    const Network::Status networkStatus = Network::status();
    const bool controllerActive = networkStatus == Network::Status::ControllerActive;
    if (!controllerActive) {
        Motor::setSpeed(0, 0);
    }

    if (Sonar::poll(distanceM) && controllerActive) {
        Network::sendDistance(distanceM);
    }

    Motor::drive();
    StatusDisplay::update(networkStatus);
}
