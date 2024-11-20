import socket
import time
import os
import random
import json
import struct
from datetime import datetime, timezone, timedelta

MULTICAST_GROUP = '224.0.0.1'
PORT = 4225

class DroneMessageGenerator:
   def __init__(self):
       self.lat_range = (25.0, 49.0)
       self.lon_range = (-125.0, -67.0)
       self.msg_index = 0
       self.start_time = time.time()
   
   def get_timestamps(self):
      now = datetime.now(timezone.utc)
      time_str = now.strftime("%Y-%m-%dT%H:%M:%SZ")
      stale = (now + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ")
      return time_str, time_str, stale
   def generate_original_format(self):
       time_str, start_str, stale_str = self.get_timestamps()
       lat = round(random.uniform(*self.lat_range), 4)
       lon = round(random.uniform(*self.lon_range), 4)
       drone_id = f"DRONE{random.randint(100,999)}"
       
       # Random drone type generation
       base_type = "a-f-G"
       type_suffixes = ["-U", "-U-C", "-U-S", "-U-R", "-U-F"]
       drone_type = base_type + random.choice(type_suffixes)
       
       # Add operator modifier randomly
       if random.random() < 0.5:
           drone_type += "-O"
           
       return f"""<event version="2.0" uid="drone-{drone_id}" type="{drone_type}" time="{time_str}" start="{start_str}" stale="{stale_str}" how="m-g">
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
       
       # Random ID type
       id_types = [
           "Serial Number (ANSI/CTA-2063-A)",
           "CAA Registration ID", 
           "UTM (USS) Assigned ID",
           "Operator ID"
       ]
       
       if random.random() < 0.1:
           lat, lon = 0.000000, 0.000000
       else:
           lat = round(random.uniform(*self.lat_range), 6)
           lon = round(random.uniform(*self.lon_range), 6)
       
       message = {
           "index": self.msg_index,
           "runtime": runtime,
           "Basic ID": {
               "id": "NONE",
               "id_type": random.choice(id_types)
           },
           "Location/Vector Message": {
               "latitude": lat,
               "longitude": lon, 
               "speed": 0 if lat == 0 else round(random.uniform(0, 30), 1),
               "vert_speed": 0 if lat == 0 else round(random.uniform(-5, 5), 1),
               "geodetic_altitude": 0 if lat == 0 else round(random.uniform(50, 400), 1),
               "height_agl": 0 if lat == 0 else round(random.uniform(20, 200), 1)
           },
           "Self-ID Message": {
               "text": "UAV NONE operational"
           },
           "System Message": {
               "latitude": 0.000000 if lat == 0 else round(lat + random.uniform(-0.001, 0.001), 6),
               "longitude": 0.000000 if lon == 0 else round(lon + random.uniform(-0.001, 0.001), 6)
           }
       }
       self.msg_index += 1
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
       print("🐉 DragonLink Multicast Test Data Broadcaster 🐉")
       print("\n1. Original Format")
       print("2. ESP32 Format") 
       print("3. Exit")
       
       choice = input("\nEnter your choice (1-3): ")
       
       if choice == '3':
           print("\n👋 Goodbye!")
           break
           
       if choice in ['1', '2']:
           interval = get_valid_number("\nEnter broadcast interval in seconds (0.1-60): ", 0.1, 60)
           
           sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
           sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
           ttl = struct.pack('b', 1)
           sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, ttl)
           
           format_name = "Original" if choice == '1' else "ESP32"
           
           clear_screen()
           print(f"🚀 Multicasting {format_name} format messages every {interval} seconds")
           print(f"Group: {MULTICAST_GROUP}:{PORT}")
           print("Press Ctrl+C to return to menu\n")
           
           try:
               while True:
                   message = (generator.generate_original_format() if choice == '1' 
                            else generator.generate_esp32_format())
                   sock.sendto(message.encode(), (MULTICAST_GROUP, PORT))
                   print(f"📡 Sent {format_name} message at {time.strftime('%H:%M:%S')}")
                   if choice == '2':
                       print(message + "\n")
                   time.sleep(interval)
           except KeyboardInterrupt:
               print("\n\n🛑 Multicast stopped")
               sock.close()
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