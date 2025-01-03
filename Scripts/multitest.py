#!/usr/bin/env python3

import socket
import time
import os
import random
import json
import string
import struct
import zmq
from datetime import datetime, timezone, timedelta

class Config:
	def __init__(self):
		self.multicast_group = '224.0.0.1'
		self.cot_port = 6969
		self.status_port = 6969
		self.broadcast_mode = 'multicast'  # or 'zmq'
		self.zmq_host = '0.0.0.0'
		
class DroneMessageGenerator:
	def __init__(self):
		self.lat_range = (25.0, 49.0)
		self.lon_range = (-125.0, -67.0)
		self.msg_index = 0
		self.start_time = time.time()
		
	def generate_complete_message(self, mode="zmq"):
		now = datetime.now(timezone.utc)
		timestamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
		
		latitude = round(random.uniform(*self.lat_range), 6)
		longitude = round(random.uniform(*self.lon_range), 6)
		rssi = random.randint(-90, -40)
		
		message = [
			{
				"Basic ID": {
					"protocol_version": "F3411.19",
					"id_type": "Serial Number (ANSI/CTA-2063-A)",
					"ua_type": "Helicopter (or Multirotor)",
					"id": f"{random.randint(10000000, 99999999)}{random.choice(string.ascii_uppercase)}291",
					"MAC": "8e:3b:93:22:33:fa",
					"rssi": rssi
				}
			},
			{
				"Basic ID": {
					"protocol_version": "F3411.19",
					"id_type": "CAA Assigned Registration ID",
					"ua_type": "Helicopter (or Multirotor)",
					"id": "HS720"
				}
			},
			{
				"AUX_ADV_IND": {
					"ts": time.time(),
					"aa": 2391391958,
					"rssi": rssi,
					"chan": random.randint(0, 39),
					"phy": 2,
					"event": 0
				}
			},
			{
				"Location/Vector Message": {
					"latitude": latitude,
					"longitude": longitude,
					"geodetic_altitude": round(random.uniform(50.0, 400.0), 2),
					"height_agl": round(random.uniform(20.0, 200.0), 2),
					"speed": round(random.uniform(0.0, 30.0), 1),
					"vert_speed": round(random.uniform(-5.0, 5.0), 1),
					"timestamp": timestamp,
				}
			},
			{
				"Self-ID Message": {
					"protocol_version": "F3411.22",
					"text": "Test UAV operation",
					"text_type": "Text Description"
				}
			},
			{
				"Authentication Message": {
					"auth_type": "Message Set Signature",
					"page_number": 0,
					"last_page_index": 0,
					"timestamp": "2019-01-01 00:00 UTC",
					"timestamp_raw": 0,
					"auth_data": "0000000000000000000000000000000000",
					"protocol_version": "F3411.19"
				}
			},
			{
				"Operator ID Message": {
					"protocol_version": "F3411.22",
					"operator_id_type": "Operator ID",
					"operator_id": "Terminator0x00"
				}
			}
		]
		
		if mode == "zmq":
			return json.dumps(message, indent=4)
		elif mode == "multicast":
			return json.dumps(message)


		def generate_bt45_message(self):
			"""Generate BT4/5 message with complete field set"""
		now = datetime.now(timezone.utc)
		timestamp = now.strftime("%Y-%m-%d %H:%M:%S UTC")
		timestamp_raw = int(now.timestamp())
		
		message = {
			"AUX_ADV_IND": {
				"aa": 0x8e89bed6,
				"addr": f"DRONE{random.randint(100,103)}",
				"rssi": random.randint(-90, -40)
			},
			"AdvData": (
				# This would be the actual OpenDroneID BT4/5 payload
				"16FFFA0D" +
				"0123456789ABCDEF0123456789ABCDEF" +
				"0123456789ABCDEF0123456789ABCDEF"
			),
			"Basic ID": [
				{
					"protocol_version": "F3411.22",
					"id_type": "Serial Number (ANSI/CTA-2063-A)",
					"ua_type": "Helicopter (or Multirotor)",
					"id": f"{random.randint(100000, 999999)}",
					"MAC": "8e:3b:93:22:33:fa",
				},
				{
					"protocol_version": "F3411.22",
					"id_type": "CAA Assigned Registration ID",
					"ua_type": "Helicopter (or Multirotor)",
					"id": "DJI",
				}
			],
			"Location/Vector Message": {
				"op_status": "Airborne",
				"height_type": "Above Takeoff",
				"ew_dir_segment": "East",
				"speed_multiplier": "0.25",
				"direction": 87,
				"speed": "0.25 m/s",
				"vert_speed": "-1.0 m/s",
				"latitude": round(random.uniform(*self.lat_range), 6),
				"longitude": round(random.uniform(*self.lon_range), 6),
				"pressure_altitude": "Undefined",
				"geodetic_altitude": "64.5 m",
				"height_agl": "45 m",
				"vertical_accuracy": "<10 m",
				"horizontal_accuracy": "<1 m",
				"baro_accuracy": "<45 m",
				"speed_accuracy": "<1 m/s",
				"timestamp": timestamp,
				"timestamp_accuracy": "0.2 s"
			},
			"Authentication Message": {
				"auth_type": "Message Set Signature",
				"auth_data": "0" * 64,
				"page_number": 0,
				"last_page_index": 0,
				"protocol_version": "F3411.22",
				"timestamp": timestamp,
				"timestamp_raw": timestamp_raw
			},
			"Self-ID Message": {
				"protocol_version": "F3411.22",
				"text": "Drones ID test flight",
				"text_type": "Text Description",
			},
			"System Message": {
				"operator_location_type": "Takeoff",
				"classification_type": "EU",
				"latitude": round(random.uniform(*self.lat_range), 6),
				"longitude": round(random.uniform(*self.lon_range), 6),
				"area_count": 1,
				"area_radius": 0,
				"area_ceiling": 0,
				"ua_classification_category_type": "Open",
				"ua_classification_category_class": "Class 1",
				"geodetic_altitude": "64.5 m",
				"timestamp": timestamp,
				"timestamp_raw": timestamp_raw
			},
			"Operator ID Message": {
				"protocol_version": "F3411.22",
				"operator_id_type": "Operator ID",
				"operator_id": ""
			}
		}
		return json.dumps(message)
	
	def generate_wifi_message(self):
		"""Generate WiFi format message with DroneID structure"""
		mac = f"WIFI-{random.randint(100000,999999)}"
		now = datetime.now(timezone.utc)
		timestamp = now.strftime("%Y-%m-%d %H:%M:%S UTC")
		timestamp_raw = int(now.timestamp())
		
		message = {
			"DroneID": {
				mac: {
					"AdvData": "16FFFA0D" + "0" * 64,  # OpenDroneID payload as hex
					"Basic ID": {
						"protocol_version": "F3411.22",
						"id_type": "Serial Number (ANSI/CTA-2063-A)",
						"ua_type": "Helicopter (or Multirotor)",
						"id": mac,
						"MAC": "8e:3b:93:22:33:fa",
						"rssi": random.randint(-90, -40)
					},
					"Location/Vector Message": {
						"op_status": "Airborne",
						"height_type": "Above Takeoff",
						"speed_multiplier": "0.25",
						"direction": 87,
						"speed": "0.25 m/s",
						"vert_speed": "-1.0 m/s",
						"latitude": round(random.uniform(*self.lat_range), 6),
						"longitude": round(random.uniform(*self.lon_range), 6),
						"pressure_altitude": "Undefined",
						"geodetic_altitude": "64.5 m",
						"height_agl": "45 m",
						"timestamp": timestamp
					},
					"System Message": {
						"operator_location_type": "Takeoff",
						"latitude": round(random.uniform(*self.lat_range), 6),
						"longitude": round(random.uniform(*self.lon_range), 6),
						"timestamp": timestamp,
						"timestamp_raw": timestamp_raw
					},
					"Self-ID Message": {
						"text": f"WiFi Drone {mac}",
						"text_type": "Text Description"
					},
					"MAC": mac
				}
			}
		}
		
		return json.dumps(message)
	
	def get_timestamps(self):
		now = datetime.now(timezone.utc)
		time_str = now.strftime("%Y-%m-%dT%H:%M:%SZ")
		stale = (now + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ")
		return time_str, time_str, stale
	
	def generate_original_format(self):
		time_str, start_str, stale_str = self.get_timestamps()
		lat = round(random.uniform(*self.lat_range), 4)
		lon = round(random.uniform(*self.lon_range), 4)
		drone_id = f"DRONE{random.randint(100,103)}"  # Only use 4 possible drones
		rssi = random.randint(-90, -40)
		
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
					<AUX_ADV_IND>
						<rssi>{random.randint(-90, -40)}</rssi>
					</AUX_ADV_IND>
					<BasicID>
						<DeviceID>{drone_id}</DeviceID>
						<Type>Serial Number</Type>
						<MAC>8e:3b:93:22:33:fa</MAC>
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
		"""Generate a telemetry message in ESP32-compatible format"""
		now = datetime.now(timezone.utc)
		latitude = round(random.uniform(*self.lat_range), 6)
		longitude = round(random.uniform(*self.lon_range), 6)
		
		message = {
			"Basic ID": {
				"id": f"{random.randint(1000, 1002)}",
				"id_type": "Serial Number (ANSI/CTA-2063-A)",
				"MAC": "8e:3b:93:22:33:fa",
				"rssi": random.randint(-90, -40)
			},
			"Location/Vector Message": {
				"latitude": latitude,
				"longitude": longitude,
				"geodetic_altitude": round(random.uniform(50.0, 400.0), 2),
				"speed": round(random.uniform(0.0, 30.0), 1),
				"vert_speed": round(random.uniform(-5.0, 5.0), 1),
			},
			"Self-ID Message": {
				"text": "ESP32 UAV active",
			},
		}
		return json.dumps(message, indent=4)
	
	def generate_status_message(self):
				runtime = int(time.time() - self.start_time)
				current_time = datetime.now(timezone.utc)
				time_str = current_time.strftime("%Y-%m-%dT%H:%M:%S.%fZ")
				stale_str = (current_time + timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
				lat = round(random.uniform(*self.lat_range), 6)
				lon = round(random.uniform(*self.lon_range), 6)
		
				# Generate system stats
				serial_number = f"wardragon-{random.randint(100,102)}"
				cpu_usage = round(random.uniform(0, 100), 1)
		
				# Memory in MB
				total_memory = 8192
				available_memory = round(random.uniform(total_memory * 0.3, total_memory * 0.8), 2)
		
				# Disk in MB
				total_disk = 512000
				used_disk = round(random.uniform(total_disk * 0.1, total_disk * 0.9), 2)
		
				message = f"""<?xml version='1.0' encoding='UTF-8'?>
	<event version="2.0" 
							uid="{serial_number}" 
							type="b-m-p-s-m" 
							time="{time_str}" 
							start="{time_str}" 
							stale="{stale_str}" 
							how="m-g">
		<point lat="{lat}" lon="{lon}" hae="1236" ce="35.0" le="999999"/>
		<detail>
				<contact endpoint="" phone="" callsign="{serial_number}"/>
				<precisionlocation geopointsrc="gps" altsrc="gps"/>
				<remarks>CPU Usage: {cpu_usage}%, Memory Total: {total_memory} MB, Memory Available: {available_memory} MB, Disk Total: {total_disk} MB, Disk Used: {used_disk} MB, Temperature: {round(random.uniform(30, 70), 1)}°C, Uptime: {runtime} seconds</remarks>
				<color argb="-256"/>
				<usericon iconsetpath="34ae1613-9645-4222-a9d2-e5f243dea2865/Military/Ground_Vehicle.png"/>
		</detail>
	</event>"""
		
				return message
	
def setup_zmq():
	context = zmq.Context()
	cot_socket = context.socket(zmq.PUB)
	status_socket = context.socket(zmq.PUB)
	return context, cot_socket, status_socket

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
			
def configure_settings(config):
	clear_screen()
	print("📝 Configure Settings")
	print("\n1. Change Broadcast Mode")
	print("2. Change Host/Group")
	print("3. Change CoT Port")
	print("4. Change Status Port")
	print("5. Back to Main Menu")
	
	choice = input("\nEnter your choice (1-5): ")
	
	if choice == '1':
		mode = input("Enter broadcast mode (multicast/zmq): ").lower()
		if mode in ['multicast', 'zmq']:
			config.broadcast_mode = mode
			
	elif choice == '2':
		if config.broadcast_mode == 'multicast':
			config.multicast_group = input("Enter multicast group (e.g., 0.0.0.0): ")
		else:
			config.zmq_host = input("Enter ZMQ host (e.g., 127.0.0.1): ")
			
	elif choice == '3':
		try:
			config.cot_port = int(input("Enter CoT port: "))
		except ValueError:
			print("Invalid port number")
			
	elif choice == '4':
		try:
			config.status_port = int(input("Enter Status port: "))
		except ValueError:
			print("Invalid port number")
			
def main_menu():
	config = Config()
	generator = DroneMessageGenerator()
	
	while True:
		clear_screen()
		print("🐉 DragonLink Test Data Broadcaster 🐉")
		print("\nCurrent Settings:")
		print(f"Mode: {config.broadcast_mode}")
		print(f"Host/Group: {config.multicast_group if config.broadcast_mode == 'multicast' else config.zmq_host}")
		print(f"CoT Port: {config.cot_port}")
		print(f"Status Port: {config.status_port}")
		
		print("\n1. Original Format")
		print("2. ESP32 Format")
		print("3. Status Messages")
		print("4. Broadcast All")
		print("5. Configure Settings")
		print("6. Exit")
		
		choice = input("\nEnter your choice (1-6): ")
		
		if choice == '6':
			print("\n👋 Goodbye!")
			break
		
		if choice == '5':
			configure_settings(config)
			continue
		
		if choice in ['1', '2', '3', '4']:
			interval = get_valid_number("\nEnter broadcast interval in seconds (0.1-60): ", 0.1, 60)
			
			if config.broadcast_mode == 'multicast':
				# Create multicast sockets
				cot_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
				status_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
				
				# Set up multicast
				ttl = struct.pack('b', 1)
				cot_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
				status_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
				cot_sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, ttl)
				status_sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, ttl)
			else:
				# Setup ZMQ
				context, cot_sock, status_sock = setup_zmq()
				cot_sock.bind(f"tcp://{config.zmq_host}:{config.cot_port}")
				status_sock.bind(f"tcp://{config.zmq_host}:{config.status_port}")
				
			clear_screen()
			print(f"🚀 Broadcasting messages every {interval} seconds via {config.broadcast_mode}")
			print(f"CoT messages to: {config.cot_port}")
			print(f"Status messages to: {config.status_port}")
			print("Press Ctrl+C to return to menu\n")
			
			try:
				while True:
					if choice == '1':  # Original/Telemetry Format
						if config.broadcast_mode == 'multicast':
							# Multicast: Send XML format
							message = generator.generate_original_format()
						else:
							# ZMQ: Send JSON format
							message = generator.generate_complete_message(mode="zmq")
							
						# Send the chosen message
						if config.broadcast_mode == 'multicast':
							cot_sock.sendto(message.encode(), (config.multicast_group, config.cot_port))
						else:
							cot_sock.send_string(message)
							
						print(f"📡 Sent Original format message at {time.strftime('%H:%M:%S')}")
					
					elif choice == '2':  # ESP32 Format
						message = generator.generate_esp32_format()
					
						# Send the chosen message
						if config.broadcast_mode == 'multicast':
							cot_sock.sendto(message.encode(), (config.multicast_group, config.cot_port))
						else:
							cot_sock.send_string(message)
							
						print(f"📡 Sent ESP32 format message at {time.strftime('%H:%M:%S')}")
						print(message + "\n")
					
					elif choice == '3':  # Status Message
						message = generator.generate_status_message()
					
						# Send the chosen message
						if config.broadcast_mode == 'multicast':
							status_sock.sendto(message.encode(), (config.multicast_group, config.status_port))
						else:
							status_sock.send_string(message)
							
						print(f"📡 Sent Status message at {time.strftime('%H:%M:%S')}")
						print(message + "\n")
					
					elif choice == '4':  # Broadcast All Formats
						# Generate messages
						if config.broadcast_mode == 'multicast':
							telemetry_message = generator.generate_original_format()
						else:
							telemetry_message = generator.generate_complete_message(mode="zmq")
							
						esp32_message = generator.generate_esp32_format()
						status_message = generator.generate_status_message()
					
						# Send all messages
						# Telemetry
						if config.broadcast_mode == 'multicast':
							cot_sock.sendto(telemetry_message.encode(), (config.multicast_group, config.cot_port))
						else:
							cot_sock.send_string(telemetry_message)
							
						# ESP32
						if config.broadcast_mode == 'multicast':
							cot_sock.sendto(esp32_message.encode(), (config.multicast_group, config.cot_port))
						else:
							cot_sock.send_string(esp32_message)
							
						# Status
						if config.broadcast_mode == 'multicast':
							status_sock.sendto(status_message.encode(), (config.multicast_group, config.status_port))
						else:
							status_sock.send_string(status_message)
							
						# Debugging outputs
						print(f"📡 Sent Telemetry message:\n{telemetry_message}")
						print(f"📡 Sent ESP32 message:\n{esp32_message}")
						print(f"📡 Sent Status message:\n{status_message}")
					
						time.sleep(interval)
						continue  # Skip to the next iteration
				
					else:
						print("\n❌ Invalid choice. Press Enter to try again...")
						input()
						continue
				
					time.sleep(interval)
			except KeyboardInterrupt:
				print("\n\n🛑 Broadcast stopped")
				if config.broadcast_mode == 'multicast':
					cot_sock.close()
					status_sock.close()
				else:
					context.destroy()
				input("\nPress Enter to return to menu...")
				

if __name__ == "__main__":
	try:
		main_menu()
	except KeyboardInterrupt:
		print("\n\n👋 Program terminated by user")
	except Exception as e:
		print(f"\n❌ An error occurred: {e}")
		