import socket
import time
import os
import random
import json
from datetime import datetime, timedelta

BROADCAST_IP = '0.0.0.0'
COT_PORT = 4224
STATUS_PORT = 4225

class DroneMessageGenerator:
    def __init__(self):
        self.lat_range = (25.0, 49.0)
        self.lon_range = (-125.0, -67.0)
        self.msg_index = 0
        self.start_time = time.time()

    def get_timestamps(self):
        now = datetime.utcnow()
        time_str = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        stale = (now + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ")
        return time_str, time_str, stale

    def generate_original_format(self):
        time_str, start_str, stale_str = self.get_timestamps()
        lat = round(random.uniform(*self.lat_range), 4)
        lon = round(random.uniform(*self.lon_range), 4)
        drone_id = f"DRONE{random.randint(100,999)}"
        
        return f"""<event version="2.0" uid="drone-{drone_id}" type="a-f-G-U-C" time="{time_str}" start="{start_str}" stale="{stale_str}" how="m-g">
    <point lat="{lat}" lon="{lon}" hae="100" ce="9999999" le="9999999"/>
    <detail>
        <BasicID>
            <DeviceID>{drone_id}</DeviceID>
            <Type>Serial Number</Type>
        </BasicID>
        <LocationVector>
            <Speed>{round(random.uniform(0, 30), 1)}</Speed>
            <VerticalSpeed>{round(random.uniform(-5, 5), 1)}</VerticalSpeed>
            <Altitude>{round(random.uniform(50, 400), 1)}</Altitude>
            <Height>{round(random.uniform(20, 200), 1)}</Height>
        </LocationVector>
        <SelfID>
            <Description>Test Drone {drone_id}</Description>
        </SelfID>
        <System>
            <PilotLocation>
                <lat>{lat + random.uniform(-0.001, 0.001)}</lat>
                <lon>{lon + random.uniform(-0.001, 0.001)}</lon>
            </PilotLocation>
        </System>
    </detail>
</event>"""

    def generate_esp32_format(self):
        runtime = int(time.time() - self.start_time)
        drone_id = f"DRONE{random.randint(100,999)}"
        
        lat = round(random.uniform(*self.lat_range), 6)
        lon = round(random.uniform(*self.lon_range), 6)
        
        message = {
            "index": self.msg_index,
            "runtime": runtime,
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
        self.msg_index += 1
        return json.dumps(message)

    def generate_status_message(self):
        runtime = int(time.time() - self.start_time)
        lat = round(random.uniform(*self.lat_range), 6)
        lon = round(random.uniform(*self.lon_range), 6)
        
        message = {
            "serial_number": f"DRAGON{random.randint(100,101)}",
            "runtime": runtime,
            "gps_data": {
                "latitude": lat,
                "longitude": lon,
                "altitude": round(random.uniform(0, 100), 1)
            },
            "system_stats": {
                "cpu_usage": round(random.uniform(0, 100), 1),
                "memory": {
                    "total": 8589934592,
                    "available": round(random.uniform(2147483648, 8589934592))
                },
                "disk": {
                    "total": 68719476736,
                    "used": round(random.uniform(0, 68719476736))
                },
                "temperature": round(random.uniform(30, 70), 1),
                "uptime": runtime
            }
        }
        return json.dumps(message)

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def get_valid_number(prompt, min_val, max_val):
    while True:
        try:
            value = float(input(prompt))
            if min_val <= value <= max_val:
                return value
            print(f"Please enter a number between {min_val} and {max_val}")
        except ValueError:
            print("Please enter a valid number")

def main_menu():
    generator = DroneMessageGenerator()
    
    while True:
        clear_screen()
        print("🐉 DragonLink Test Data Broadcaster 🐉")
        print("\n1. Original Format")
        print("2. ESP32 Format")
        print("3. Status Messages")
        print("4. Broadcast All")
        print("5. Exit")
        
        choice = input("\nEnter your choice (1-5): ")
        
        if choice == '5':
            print("\n👋 Goodbye!")
            break
            
        if choice in ['1', '2', '3', '4']:
            interval = get_valid_number("\nEnter broadcast interval in seconds (0.1-60): ", 0.1, 60)
            
            cot_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            status_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            cot_address = (BROADCAST_IP, COT_PORT)
            status_address = (BROADCAST_IP, STATUS_PORT)
            
            clear_screen()
            print(f"🚀 Broadcasting messages every {interval} seconds")
            if choice in ['1', '2', '4']:
                print(f"CoT messages to: {BROADCAST_IP}:{COT_PORT}")
            if choice in ['3', '4']:
                print(f"Status messages to: {BROADCAST_IP}:{STATUS_PORT}")
            print("Press Ctrl+C to return to menu\n")
            
            try:
                while True:
                    if choice in ['1', '4']:
                        message = generator.generate_original_format()
                        cot_sock.sendto(message.encode(), cot_address)
                        print(f"📡 Sent Original message at {time.strftime('%H:%M:%S')}")
                        
                    if choice in ['2', '4']:
                        message = generator.generate_esp32_format()
                        cot_sock.sendto(message.encode(), cot_address)
                        print(f"📡 Sent ESP32 message at {time.strftime('%H:%M:%S')}")
                        print(message + "\n")
                        
                    if choice in ['3', '4']:
                        message = generator.generate_status_message()
                        status_sock.sendto(message.encode(), status_address)
                        print(f"📡 Sent Status message at {time.strftime('%H:%M:%S')}")
                        print(message + "\n")
                        
                    time.sleep(interval)
            except KeyboardInterrupt:
                print("\n\n🛑 Broadcast stopped")
                cot_sock.close()
                status_sock.close()
                input("\nPress Enter to return to menu...")
        else:
            print("\n❌ Invalid choice. Press Enter to try again...")
            input()

if __name__ == "__main__":
    try:
        main_menu()
    except KeyboardInterrupt:
        print("\n\n👋 Program terminated by user")
    except Exception as e:
        print(f"\n❌ An error occurred: {e}")
