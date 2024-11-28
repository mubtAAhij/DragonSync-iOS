# DragonSync iOS
<p align="left">
  <img src="https://github.com/user-attachments/assets/35f7de98-7256-467d-a983-6eed49e90796" alt="Dragon Logo" width="175">
</p>

_**TestFlight dev build coming soon. Stay tuned...**_

## Features

This application facilitates seamless communication between your iOS device and the WarDragon platform, enabling real-time monitoring of Remote ID-compliant drones with alerts and mapping. It also displays the connected system status updates as sent by `wardragon_monitor.py` & `dragonsync.py`.

- **Real-Time Drone Monitoring**: Receive live updates on drone status and location directly on your iOS device.
- **System Status Alerts**: Stay informed about the health and performance of your WarDragon system.
- **Seamless Integration**: Built to work effortlessly with DragonSync and the WarDragon platform.
- **Multi-Protocol Support**: Integrates directly with DroneID and DragonSync using ZMQ and Multicast config options. This allows users to listen for CoT and status messages using Multicast alone or with ZMQ (depending on user needs).

## Functionality

### Display decoded DroneIDs
  - Use ESP32 & other hardware, without no need for ATAK or complex TAK servers.
<p align="left">
  <img src=https://github.com/user-attachments/assets/63f082e5-64b6-469c-9bc8-b98bc1ebc71a width="400">
</p>

### Real-time updates
  - Using the [DragonSync](https://github.com/alphafox02/DragonSync) `wardragon_monitor.py`. Supports Multicast and ZMQ. Displays CoT and status messages from the WarDragon, no setup required.
- Configurable network settings and an immersive UI. Detail views in the system and live map view show more details.
    
<p align="left">
 <img src=https://github.com/user-attachments/assets/e55ddba1-1387-4543-bec9-56d0b7f6f677 width="420")
</p>

## Inspiration & Credits

DragonSync is designed to enhance the functionality of the WarDragon system by integrating with [DragonSync](https://github.com/alphafox02/DragonSync) and [DroneID](https://github.com/bkerler/DroneID). None of this would be possible without that work. A big thanks to the devs at [Sniffle](https://github.com/nccgroup/Sniffle). And of course to [@alphafox02](https://github.com/alphafox02) for creating the WarDragon, DragonOS, the above scripts- and showing me how to make this work.


## Installation

1. Clone the Repository:
```
git clone https://github.com/Root-Down-Digital/DragonLink.git
```
2. Open in Xcode: Navigate to the cloned directory and open `WarDragon.xcodeproj` in Xcode.

3. Build and Run: Connect your iOS device and build the project in Xcode to install the app.

## Usage

- Once installed, launch DragonSync on your iOS device. Ensure that your device is connected to the same network as your WarDragon system.

- Launch the scripts from DragonSync to start the monitor and broadcast. (Specific commands to follow after testing is complete). 

- The app will automatically detect and connect to the system when you select Start Listening, providing you with real-time CoT data and status updates.

## Credits

DragonLink is built upon the foundational work of DragonSync by [cemaxecuter](cemaxecuter.com). Check out his work here on GitHub: [@alphafox02](https://github.com/alphafox02)

We extend our gratitude for their contributions to the open-source community, which have been instrumental in the development of this application.

## Disclaimer

> [!WARNING]
> This software is provided as-is, without warranty of any kind. Use at your own risk.
Root Down Digital and associated developers are not responsible for any damages, legal issues, or misuse that may arise from the use of DragonLink. Always operate drones in compliance with local laws and regulations. Ensure compatibility with your WarDragon system and associated hardware.

## License

This project is licensed under the MIT License. See the LICENSE.md file for details.

## Contributing

We welcome contributions to DragonLink. If you have suggestions or improvements, please submit a pull request or open an issue in this repository.

## Contact

For support or inquiries, please contact the development team by opening an issue.

## Additional Notes

> [!NOTE]
> DragonLink is currently in active development. Some features may be incomplete or subject to change.

> [!IMPORTANT]
> Ensure that your WarDragon system is updated to the latest firmware version for optimal compatibility with DragonLink.

> [!TIP]
> For the best experience, keep your iOS device and WarDragon system on the same local network to facilitate seamless communication.

> [!CAUTION]
> Always operate drones in compliance with local regulations and guidelines to ensure safety and legality.

> [!WARNING]
> Unauthorized use of this application with systems other than WarDragon may result in unexpected behavior or system instability
