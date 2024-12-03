import time
import os
import random
import json
import zmq
from datetime import datetime

class Config:
    def __init__(self):
        self.zmq_host = '0.0.0.0'
        self.telemetry_port = 4224  # Port for decoded drone data
        self.status_port = 4225     # Port for system status

class MessageGenerator:
    def __init__(self):
        self.start_time = time.time()

    def generate_decoded_drone_message(self, use_ble=True):
        """Emulate zmq_decoder.py output format"""
        drone_id = f"DRONE{random.randint(100,103)}"
        lat = round(random.uniform(25.0, 49.0), 6)
        lon = round(random.uniform(-125.0, -67.0), 6)
        
        if use_ble:
            message = {
                "Basic ID": {
                    "id_type": "Serial Number (ANSI/CTA-2063-A)",
                    "id": drone_id
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
                    "latitude": lat + random.uniform(-0.001, 0.001),
                    "longitude": lon + random.uniform(-0.001, 0.001)
                }
            }
        else:
            message = {
                "DroneID": {
                    f"{drone_id}-MAC": {
                        "Basic ID": {
                            "id_type": "CAA Registration ID",
                            "id": drone_id
                        },
                        "Location/Vector Message": {
                            "latitude": lat,
                            "longitude": lon,
                            "speed": round(random.uniform(0, 30), 1),
                            "vert_speed": round(random.uniform(-5, 5), 1),
                            "geodetic_altitude": round(random.uniform(50, 400), 1),
                            "height_agl": round(random.uniform(20, 200), 1)
                        }
                    }
                }
            }
        return json.dumps(message)

    def generate_system_status(self):
        """Emulate wardragon_monitor.py output format"""
        runtime = int(time.time() - self.start_time)
        
        return json.dumps({
            'timestamp': time.time(),
            'gps_data': {
                'latitude': round(random.uniform(25.0, 49.0), 6),
                'longitude': round(random.uniform(-125.0, -67.0), 6),
                'altitude': round(random.uniform(0, 1000), 1),
                'speed': round(random.uniform(0, 30), 1)
            },
            'serial_number': f"wardragon-{random.randint(100,102)}",
            'system_stats': {
                'cpu_usage': round(random.uniform(0, 100), 1),
                'memory': {
                    'total': 8589934592,
                    'available': random.randint(2147483648, 6442450944),
                    'percent': round(random.uniform(20, 80), 1),
                    'used': random.randint(2147483648, 6442450944),
                    'free': random.randint(2147483648, 6442450944)
                },
                'disk': {
                    'total': 256000000000,
                    'used': random.randint(50000000000, 200000000000),
                    'free': random.randint(50000000000, 200000000000),
                    'percent': round(random.uniform(20, 80), 1)
                },
                'temperature': round(random.uniform(30, 70), 1),
                'uptime': runtime
            }
        })

def setup_zmq():
    context = zmq.Context()
    telemetry_socket = context.socket(zmq.PUB)
    status_socket = context.socket(zmq.PUB)
    return context, telemetry_socket, status_socket

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def main():
    config = Config()
    generator = MessageGenerator()
    
    while True:
        clear_screen()
        print("🐉 DragonSync Test Publisher 🐉")
        print("\nPublishing to:")
        print(f"Telemetry: {config.zmq_host}:{config.telemetry_port}")
        print(f"Status: {config.zmq_host}:{config.status_port}")
        
        print("\n1. Send BLE Drone Messages")
        print("2. Send WiFi DroneID Messages")
        print("3. Send System Status")
        print("4. Send All Types")
        print("5. Exit")
        
        choice = input("\nChoice (1-5): ")
        
        if choice == '5':
            break
            
        if choice in ['1', '2', '3', '4']:
            try:
                interval = float(input("\nSend interval in seconds (0.1-60): "))
                if not (0.1 <= interval <= 60):
                    print("Interval must be between 0.1 and 60 seconds")
                    continue
            except ValueError:
                print("Invalid interval")
                continue

            context, telemetry_socket, status_socket = setup_zmq()
            telemetry_socket.bind(f"tcp://{config.zmq_host}:{config.telemetry_port}")
            status_socket.bind(f"tcp://{config.zmq_host}:{config.status_port}")

            print(f"\n🚀 Publishing test data every {interval} seconds")
            print("Press Ctrl+C to stop\n")
            
            try:
                while True:
                    if choice in ['1', '4']:
                        message = generator.generate_decoded_drone_message(use_ble=True)
                        telemetry_socket.send_string(message)
                        print(f"📡 Sent BLE drone message")

                    if choice in ['2', '4']:
                        message = generator.generate_decoded_drone_message(use_ble=False)
                        telemetry_socket.send_string(message)
                        print(f"📡 Sent WiFi drone message")

                    if choice in ['3', '4']:
                        message = generator.generate_system_status()
                        status_socket.send_string(message)
                        print(f"📡 Sent system status")

                    time.sleep(interval)
                    
            except KeyboardInterrupt:
                print("\n🛑 Publishing stopped")
                context.destroy()
                input("\nPress Enter to continue...")

if __name__ == "__main__":
    try:
        main()
        print("\n👋 Goodbye!")
    except Exception as e:
        print(f"\n❌ Error: {e}")