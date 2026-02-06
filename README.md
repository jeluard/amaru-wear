A WearOS application that displays the latest Cardano blockchain tip in real-time using [Amaru](https://github.com/pragma-org/amaru) node implementation.

<p align="center" width="100%">
<video src="[https://github.com/user-attachments/assets/a91c01d9-d570-4f31-bd33-cfe13a505c2b](https://github.com/user-attachments/assets/b52a01eb-843e-4f20-afc3-f5fecaa34fe3)" width="50%" controls></video>
</p>

## 🚀 Quick Start

```bash
# Setup once
make setup

# Launch on emulator
make launch

# Or deploy to watch
make deploy
```

## 🛠️ Troubleshooting

**Logs not showing**
```bash
adb logcat | grep -E "(AmaruWear|amaru_wear)"
```

**Watch not connecting**
* Enable WiFi ADB in developer options
* Verify same network
* Try: `adb disconnect && adb connect <ip>:5555`
