# DragonSync iOS

<p align="center">
  <img src="https://github.com/user-attachments/assets/35f7de98-7256-467d-a983-6eed49e90796" alt="Dragon Logo" width="220">
</p>



DragonSync is an iOS app designed to enhance the functionality of the WarDragon system by integrating with [DragonSync](https://github.com/alphafox02/DragonSync) and [DroneID](https://github.com/bkerler/DroneID). 

None of this would be possible without them, and especially the devs of [Sniffle](https://github.com/nccgroup/Sniffle). 

---

## Features

This application facilitates seamless communication between your iOS device and the WarDragon platform, enabling real-time monitoring and control of Remote ID-compliant drones.

- **Real-Time Drone Monitoring**: Receive live updates on drone status and location directly on your iOS device.
- **System Status Alerts**: Stay informed about the health and performance of your WarDragon system.
- **Seamless Integration**: Built to work effortlessly with DragonSync and the WarDragon platform.

## Current Functionality

- Display decoded DroneIDs from ESP32 & other hardware without TAK servers or intricate setup
![image](https://github.com/user-attachments/assets/63f082e5-64b6-469c-9bc8-b98bc1ebc71a)

![image](https://github.com/user-attachments/assets/1e4ebd30-01a2-4158-9422-4c65b21fa18b)


- Monitor system status using the [DragonSync](https://github.com/alphafox02/DragonSync) `wardragon_monitor.py`
   
- The dedicated service port offers automatic UI updates and supports multiple systems:
![image](https://github.com/user-attachments/assets/197d5703-90e2-4485-8af7-8bd6c46f44fb)


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
