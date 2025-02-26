# DragonSync iOS  

<div align="center">
 <img src="https://github.com/user-attachments/assets/d21ab909-7dba-4b42-8996-a741248e9223" width="80%" alt="DragonSync Logo">
</div>
<br>
<div align="center"> 
Real-time drone detection and monitoring for iOS, powered by WarDragon. DragonSync brings professional-grade drone detection to your mobile device with advanced signal analysis and comprehensive tracking capabilities.
</div>
   
<div align="center">
<br>

[![TestFlight Beta](https://img.shields.io/badge/TestFlight-Join_Beta-blue.svg)](https://testflight.apple.com/join/QKDKMSfA)

</div>

## Table of Contents  

### Features  
- [Real-Time Monitoring](#real-time-monitoring)  
- [Spoof Detection](#spoof-detection)  
- [MAC Randomization Detection](#mac-randomization-detection)  
- [Multi-Source Signal Analysis](#multi-source-signal-analysis)  
- [System Monitoring](#system-monitoring)  
- [Encounter History](#encounter-history)  

### Detection & Tracking  
- [Dashboard Display](#dashboard-display)  
- [Live Drone View](#live-drone-view)  

### History & Analysis  
- [Encounter History](#encounter-history-1)  

### App Settings Configuration  
- [Warning Dials](#warning-dials)  

### Requirements  
- [Option 1: WarDragon/Pro](#option-1-wardragonpro)  
- [Option 2: DIY Setup](#option-2-diy-setup)  
  - [Hardware Requirements](#hardware-requirements)  
  - [Software Requirements](#software-requirements)  

### Usage  
- [Connection Methods](#connection-methods)  
  - [ZMQ Server (JSON) - Recommended](#zmq-server-json---recommended)  
  - [Multicast (CoT) - Experimental](#multicast-cot---experimental)  
- [Setup Instructions](#setup-instructions)  
  - [ZMQ Connection](#zmq-connection)  
  - [Multicast Setup](#multicast-setup)  
- [Settings Configuration](#settings-configuration)  

### Building from Source
- [Xcode](#build-instructions)  

### Community & Legal  
- [Credits](#credits)  
- [Disclaimer](#disclaimer)  
- [License](#license)  
- [Contributing](#contributing)  
- [Contact](#contact)  
- [Notes](#notes)  


## Features

### Real-Time Monitoring
* Live tracking of Remote ID-compliant drones.
* Decodes Ocusync and others that do not use Remote ID
* Instant flight path visualization
* Comprehensive telemetry data
* Multi-protocol (ZMQ and multicast)
* Simultaneous tri-source detection

<div align="center">
 <img src="https://github.com/user-attachments/assets/58a6861d-5a06-4e6b-b862-566f2f8a988b" width="60%" alt="Drone Detection Screenshot">
</div>
  

### Spoof Detection
Advanced signal analysis algorithms identify potential spoofed transmissions through:
* Signal strength validation
* Position consistency checks
* Transmission pattern analysis
* Flight physics validation

<div align="center">
 <img src="https://github.com/user-attachments/assets/b06547b7-4f04-4e80-a562-232b96cc8a5b" width="60%" alt="Spoof Detection Screenshot">
</div>

### MAC Randomization Detection
Automatically identifies and tracks MAC address changes:
* Real-time MAC change alerts
* Association with origin IDs
* Historical MAC tracking
* Randomization pattern detection

<div align="center">
 <img src="https://github.com/user-attachments/assets/a6c0698f-944d-4a41-b38c-fca75778a5e8" width="60%" alt="MAC Randomization Detection Screenshot">
</div>

### Multi-Source Signal Analysis
* Signal type identification (WiFi/BT/SDR)
* Source MAC address tracking
* Signal strength monitoring
<div align="center">
 <img src="https://github.com/user-attachments/assets/4763ffb4-f8ef-4e42-af17-a22c27b798a5" width="70%" alt="Signal Analysis Interface">
</div>


<div align="center">
 <img src="https://github.com/user-attachments/assets/4477787a-8877-4421-88b8-ffd7ec38e26b" width="70%" alt="Signal Analysis Interface">
</div>

### System Monitoring
* Real-time performance metrics
* Memory usage tracking
* CPU load & temperature displays
* GPS status tracking
* ANTSDR temperature monitoring

<div align="center">
 <img src="https://github.com/user-attachments/assets/b384b0b1-8a90-48c6-bf3a-bcf41b599703" width="60%" alt="System Monitoring Dashboard">
</div>

### Encounter History
* Automatic drone encounter logging
* Searchable history database
* CSV/KML export options
* Detailed flight data review
* Historical path visualization

<div align="center">
 <img src="https://github.com/user-attachments/assets/816debe7-6c05-4c7a-9e88-14a6a4f0989a" width="60%" alt="Encounter History View">
</div>


## Detection & Tracking

#### Dashboard Display
Keep tabs on your entire system at a glance:
* Live signal detection counts
* System health status 
* Critical services tracking
* Warning monitoring
* Active drones display
* Proximity and randomization

<div align="center">
  <img src="https://github.com/user-attachments/assets/063c2922-1dc5-468d-8378-bb7940d32919" width="60%" alt="Dashboard View">
</div>

#### Live Drone View
Track multiple drones in real-time with interactive maps and detailed signal analysis. Every detected drone appears in the Drones tab with:
* Live flight path tracking 
* Signal source identification
* Manufacturer detection
* Spoof analysis
* MAC randomization monitoring

> [!TIP]
> To get a better view:
> * Tap the "Live" map button for full-screen tracking
> * Select from Active Drones to view full details
> * Watch for color changes indicating signal strength or alerts

### History & Analysis

#### Encounter History
Every detected drone is automatically logged with:
* Flight paths
* Signal data
* Location information
* Operator positions when available
* Takeoff locations (SDR only)
* MAC history

Access this data through the History tab:
* Search by ID or CAA registration
* Sort by various metrics
* Review flight details
* Export data in CSV/KML formats
* Delete individual records with left swipe
* Clear all history via menu

## App Settings Configuration

#### Warning Dials
Customize dashboard alerts with the control dials:
* CPU Usage threshold
* System temperature limits
* Memory usage warnings
* PLUTO temperature monitoring
* ZYNQ temperature alerts
* Proximity warning RSSI


<div align="center">
  <img src="https://github.com/user-attachments/assets/3a3651c2-38c5-4eab-902a-d61198e677c0" width="70%" alt="Warning Configuration">
</div>

Set proximity warnings based on signal strength - useful for:
* Close range detection
* Approach alerts
* Zone monitoring
* Signal strength tracking


## Requirements

### Option 1: [WarDragon/Pro](https://cemaxecuter.com/?post_type=product)

### Option 2: DIY Setup

#### Hardware Requirements
* ESP32 with WiFi RID [Firmware](https://github.com/alphafox02/T-Halow) or compatible WiFi adapter running DroneID wifi_sniffer. 
* Sniffle compatible BT dongle (flashed with latest sniffle FW)
* ANTSDR E200 (Optional: For ocusync decoding)
* GPS unit (Optional: For spoof detection and status location)

#### Software Requirements
* [Sniffle](https://github.com/nccgroup/Sniffle)
* [DroneID](https://github.com/alphafox02/DroneID)
* [DragonSync Python](https://github.com/alphafox02/DragonSync)

Optional:
* [DJI Firmware - E200](https://github.com/alphafox02/antsdr_dji_droneid)
* [WiFi Remote ID Firmware - ESP32](https://github.com/alphafox02/T-Halow/tree/wifi_rid/examples/DragonOS_RID_Scanner)

## Usage

> [!NOTE]
> Keep your DroneID and DragonSync repositories updated. Update by running `git pull` in both repository directories.

> [!TIP]
> **BYOD - Getting Started**
>
> *ZMQ offers several advantages over CoT XML messages. Firstly, it provides a direct device connection, utilizing only a single decoder. This design ensures greater reliability and robustness. Secondly, ZMQ uses all available data while CoT does not.*
> - Use the `--dji` flag with zmq_decoder as demonstrated in the DroneID docs for SDR decoding.
> - Using `wardragon-monitor.py` will report data on most any linux system: `wardragon_monitor.py --zmq_host 0.0.0.0 --zmq_port 4225 --interval 30`
> - Running `zmq_decoder.py`
>    - Using a wireless adapter:
>        - First run the wifi sniffer
>      `./wifi_receiver.py --interface wlan0 -z --zmqsetting 127.0.0.1:4223`
>        - Start  `python3 zmq_decoder.py -z --zmqsetting 0.0.0.0:4224 --zmqclients 127.0.0.1:4222,127.0.0.1:4223 -v`
>    - Using ESP32: `python3 zmq_decoder.py -z --uart /dev/esp0 --zmqsetting 0.0.0.0:4224 --zmqclients 127.0.0.1:4222 -v` (replace /dev/esp0 with your port)
> - Starting Sniffle BT for Sonoff baud (CatSniffer, don't set -b): `python3 Sniffle/python_cli/sniff_receiver.py -l -e -a -z -b 2000000`

### Connection Methods

#### ZMQ Server (JSON) - Recommended
* Full data access
* Direct ZMQ connection
* Minimal configuration needed
* Complete feature support

#### Multicast (CoT) - Experimental
* Limited data compared to ZMQ
* Supports multiple simultaneous instances
* Missing some advanced features

### Setup Instructions

#### ZMQ Connection
1. Connect your device to the WarDragon network
2. Select ZMQ in app settings
3. Enter WarDragon IP address
4. Start the listener
5. Monitor status and detection data

#### Multicast Setup
1. Start `dragonsync.py` and `wardragon-monitor.py`
2. Launch `zmq_decoder.py` and WiFi/BT sniffer
3. Configure network for multicast
4. Enable multicast in app settings

### Settings Configuration

<div align="center">
 <img src="https://github.com/user-attachments/assets/3a3651c2-38c5-4eab-902a-d61198e677c0" width="60%" alt="Settings Configuration">
</div>

* Adjustable warning thresholds
* Custom proximity alerts
* System monitoring preferences
* Display customization
* Connection configuration

## Build Instructions

1. Clone the repository:
repository:
`git clone https://github.com/Root-Down-Digital/DragonSync-iOS.git`

3. Install dependencies:
```
cd DragonSync-iOS
pod install
```

4. Open in Xcode:
Open `WarDragon.xcworkspace`

5. Build and deploy to your iOS device

## Credits

Special thanks to:
* [DragonSync](https://github.com/alphafox02/DragonSync)
* [DroneID](https://github.com/bkerler/DroneID)
* [Sniffle](https://github.com/nccgroup/Sniffle)
* [@alphafox02](https://github.com/alphafox02) - WarDragon creator
* [@bkerler](https://github.com/bkerler) - DroneID development

## Disclaimer

> [!WARNING]
> This software is provided as-is, without warranty. Use at your own risk. Root Down Digital and associated developers are not responsible for damages, legal issues, or misuse. Operate in compliance with local regulations.

## License

MIT License. See LICENSE.md for details.

## Contributing

We welcome contributions! Please submit pull requests or open issues in this repository.

## Contact

For support, please open an issue in this repository.

## Notes

> [!NOTE]
> DragonSync is currently in active development. Some features may be incomplete or subject to change.

> [!IMPORTANT]
> Ensure that your WarDragon DragonOS image is updated for optimal compatibility with DragonSync.

> [!TIP]
> Keep your iOS device and WarDragon system on the same local network to ensure seamless communication.

> [!CAUTION]
> Always operate in compliance with local regulations and guidelines to ensure safety and legality.

> [!WARNING]
> Use of this application with systems other than WarDragon may result in unexpected behavior or system instability
