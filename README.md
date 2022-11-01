# EchoProber-iOS

iOS client for real-time audio playback and recording using SwiftUI and SwiftSocket.

SwiftSocket is used. Open the project via EchoProber.xcworkspace.

## Get Started

⚪ Gray button: tap to start recording in Offline Mode. Audio and sensor log files will show up in the Files app.

🟢 Green button: tap to start recording in Online Mode. Connect to [EchoProber-server](https://github.com/felixnie/EchoProber-server) to enable this mode.

## For Developers

1. iOS will only ask for permission the first time an app tries to browse your local network. EchoProber-iOS prompts the permission request by visiting https://www.apple.com

2. Sensor data includes readings from gyroscope, accelerometor and magnetometer. The sampling rate (up tp 100Hz) can be higher than the chirp rate (30Hz when chirp duration is set to 1600 samples and the sample rate is 44.1kHz). This can be re-aligned in post-processing.

## Screenshot

<img src="https://raw.githubusercontent.com/felixnie/img/master/EchoProber-iOS-01.PNG" width="450">
<img src="https://raw.githubusercontent.com/felixnie/img/master/EchoProber-iOS-02.PNG" width="450">
<img src="https://raw.githubusercontent.com/felixnie/img/master/EchoProber-iOS-03.PNG" width="450">

