#pragma once

#include "network.h"

namespace StatusDisplay {
    void begin();
    void update(Network::Status status);
} // namespace StatusDisplay
