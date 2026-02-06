A WearOS application that displays the latest Cardano blockchain tip in real-time using [Amaru](https://github.com/pragma-org/amaru) node implementation.

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
