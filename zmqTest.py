#!/usr/bin/env python3

import zmq
import time
import random
import json
from datetime import datetime, timezone

class DroneMessageGenerator:
    def __init__(self):
        self.lat_range = (25.0, 49.0) 
        self.lon_range = (-125.0, -67.0)

    def generate_message(self):
        lat = round(random.uniform(*self.lat_range), 6)
        lon = round(random.uniform(*self.lon_range), 6)
        drone_id = f"drone-{random.randint(100,103)}"

        message = {
            "Basic ID": {
                "id": drone_id,
                "id_type": "Serial Number (ANSI/CTA-2063-A)"
            },
            "Location/Vector Message": {
                "latitude": lat,
                "longitude": lon,
                "speed": round(random.uniform(0, 30), 1),
                "vert_speed": round(random.uniform(-5, 5), 1),
                "geodetic_altitude": round(random.uniform(50, 400), 1),
                "height_agl": round(random.uniform(20, 200), 1)
            },
            "Self-ID Message": {
                "text": f"Test Drone {drone_id}"
            },
            "System Message": {
                "latitude": round(lat + random.uniform(-0.001, 0.001), 6),
                "longitude": round(lon + random.uniform(-0.001, 0.001), 6)
            }
        }
        return json.dumps(message)

def main():
    context = zmq.Context()
    socket = context.socket(zmq.PUB)
    socket.bind("tcp://0.0.0.0:4224")
    
    generator = DroneMessageGenerator()
    print("Publishing drone messages on port 4224")
    
    try:
        while True:
            message = generator.generate_message()
            socket.send_string(message)
            print(f"Sent: {message}")
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping publisher")
        socket.close()
        context.term()

if __name__ == "__main__":
    main()