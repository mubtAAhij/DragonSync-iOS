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

## Features

### Real-Time Monitoring
* Live tracking of Remote ID-compliant drones
* Instant flight path visualization
* Comprehensive telemetry data display
* Multi-protocol (ZMQ and multicast)
* Simultaneous tri-source detection

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
 <img src="https://github.com/user-attachments/assets/c1514c00-df58-4231-bfff-cd3268210d6f" width="70%" alt="Signal Analysis Interface">
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

### Detection & Tracking

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

To get a better view:
* Tap the "Live" map button for full-screen tracking
* Select any drone entry to view full details
* Watch for color changes indicating signal strength or alerts


#### Advanced Spoofing Detection
When enabled, DragonSync's spoof detection provides:
* Signal strength analysis relative to reported positions
* Flight physics validation
* Position consistency monitoring
* Detailed confidence scoring
* Full breakdown of detection reasons

#### Signal Analysis 
Watch for MAC randomization and track signal changes:
* MAC address pattern detection
* Real-time association tracking
* Historical MAC mapping
* Signal type identification
* Source verification

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

### System Configuration

#### Warning Dials
Customize alerts with tactile control dials:
* CPU Usage threshold
* System temperature limits
* Memory usage warnings
* PLUTO temperature monitoring
* ZYNQ temperature alerts
* Proximity warning RSSI


<div align="center">
  <img src="https://github.com/user-attachments/assets/3a3651c2-38c5-4eab-902a-d61198e677c0" width="100%" alt="Warning Configuration">
</div>

Set proximity warnings based on signal strength - useful for:
* Close range detection
* Approach alerts
* Zone monitoring
* Signal strength tracking

#### System Monitoring
Keep tabs on your hardware:
* Real-time CPU usage
* Memory allocation
* Temperature tracking
* GPS status
* Storage space
* Network connectivity

Watch ANTSDR temperatures in Pro version:
* PLUTO core temp
* ZYNQ temperature
* Historical tracking
* Warning indicators

## Requirements

### Option 1: [WarDragon/Pro](https://cemaxecuter.com/?post_type=product)

### Option 2: DIY Setup

#### Hardware Requirements
* ESP32
* Sniffle compatible BT dongle
* ANTSDR E200
* GPS unit

#### Software Requirements
* [Sniffle](https://github.com/nccgroup/Sniffle)
* [DroneID](https://github.com/alphafox02/DroneID)
* [DragonSync Python](https://github.com/alphafox02/DragonSync)
* [DJI Firmware - E200](https://github.com/alphafox02/antsdr_dji_droneid)
* [WiFi Remote ID Firmware - ESP32](https://github.com/alphafox02/T-Halow/tree/wifi_rid/examples/DragonOS_RID_Scanner)

## Usage

> [!NOTE]
> Keep your DroneID and DragonSync repositories updated. Update by running `git pull` in both repository directories.

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
