//
//  ContentView.swift
//  EchoProber
//
//  Created by Hongtuo on 2/8/22.
//

import SwiftUI
import AVKit
import SwiftSocket
import CoreMotion


struct ContentView: View {
    var body: some View {
        Home()
            .preferredColorScheme(.dark)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


struct Home : View {
    // MARK: global variables
    // for system
    @State var infoText = ""
    @State var isPlaying = false
    @State var willAlert = false
    @State var audioSession : AVAudioSession!
    @State var client : TCPClient?
    
    // for recorder
    var audioEngine : AVAudioEngine = AVAudioEngine()
    let conversionQueue = DispatchQueue(label: "conversionQueue")
    let sampleRate = 44100
    let bufferSize = 1600 // may differ from actual sample count
    
    // for offline recorder
    @State var audioRecorder : AVAudioRecorder!
    
    // for player
    @State var audioPlayer : AVAudioPlayer!
    @State var wavLeft : [Float] = [0.0] // float sound array for left channel
    @State var wavRight : [Float] = [0.0] // float sound array for right channel
    @State var wavUpdated = false
    
    // for socket
    @AppStorage("host") var hostTextField = "155.69.142.149"
    @AppStorage("port") var portTextField = "8173"
    @State var connectedFlag = false
    @State var messageTextField = ""
    
    // for auto-stop timer
    // @State var timer : DispatchSourceTimer! // unused
    @State var pressStop : DispatchWorkItem!
    @State var isTiming = false // if a task is scheduled
    
    // for motion
    let motionManager = CMMotionManager()
    let motionQueue = OperationQueue()
    @State var startTime : Double!
    @State var timeT : [Double] = []
    @State var gyroX : [Double] = []
    @State var gyroY : [Double] = []
    @State var gyroZ : [Double] = []
    @State var accX : [Double] = []
    @State var accY : [Double] = []
    @State var accZ : [Double] = []
    @State var magX : [Double] = []
    @State var magY : [Double] = []
    @State var magZ : [Double] = []
    @State var oriPitch : [Double] = []
    @State var oriYaw : [Double] = []
    @State var oriRoll : [Double] = []
    @State var gyroRawX : [Double] = []
    @State var gyroRawY : [Double] = []
    @State var gyroRawZ : [Double] = []
    @State var accRawX : [Double] = []
    @State var accRawY : [Double] = []
    @State var accRawZ : [Double] = []
    
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                // MARK: host and port
                HStack() {
                    Text("HOST")
                        .font(.headline)
                        .bold()
                    TextField("Host IP", text: $hostTextField)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                    Text("PORT")
                        .font(.headline)
                        .bold()
                    TextField("Port", text: $portTextField)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }.padding(.horizontal)
                
                // MARK: connect and disconnect
                HStack() {
                    
                    Spacer()
                    
                    Button("Connect", action: {
                        // build connection
                        connectTCP()
                    })
                    .disabled(connectedFlag)
                    
                    Button("Disconnect", action: {
                        
                        
                        if isPlaying {
                            // same as the actions of pressing stop button
                            stopRecorder()
                            stopPlayer()
                            printInfo(message: "Stopped.")
                            isPlaying.toggle()
                        }
                        
                        // release connection
                        disconnectTCP()
                        printInfo(message: "Disconnected.")
                        connectedFlag.toggle()
                    })
                    .disabled(!connectedFlag)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                
                // MARK: message and log text
                HStack() {
                    Text("TEXT")
                        .font(.headline)
                        .bold()
                    TextField("Text Message / File Name", text: $messageTextField)
                        .textFieldStyle(.roundedBorder)
                    Button("Send", action: {
                        sendTCP(message: messageTextField)
                    })
                    .buttonStyle(.bordered)
                    .disabled(!connectedFlag)
                }.padding()
                
                Text("EVENT LOGS")
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ScrollView {
                Text(infoText)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    
                }
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 2)
                )
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 20)
                
                // MARK: play button actions
                Button(action: {
                    
                    // button behavior
                    if isPlaying && connectedFlag{ // stop actions for online mode
                        stopRecorder()
                        stopPlayer()
                        
                        printInfo(message: "Stopped.")
                        isPlaying.toggle()
                    } else if !isPlaying && connectedFlag{ // start actions for online mode
                        startRecorder()
                        startPlayer()
                        sendTCP(message: "Start playing.") // tell server to reset arrays
                        printInfo(message: "Started in online mode.")
                        isPlaying.toggle()
                    } else if isPlaying && !connectedFlag{ // stop actions for offline mode
                        stopOfflineRecorder()
                        stopOfflineTimer()
                        saveMotionData()
                        stopPlayer()
                        printInfo(message: "Stopped.")
                        isPlaying.toggle()
                    } else if !isPlaying && !connectedFlag{ // start actions for offline mode
                        startOfflineRecorder()
                        startOfflineTimer()
                        startPlayer()
                        printInfo(message: "Started in offline mode.")
                        isPlaying.toggle()
                    }
                }) {
                    // button style
                    if connectedFlag && isPlaying { // stop actions
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 6)
                            .background(Circle().foregroundColor(Color.red))
                            .frame(width: 70, height: 70)
                    } else if connectedFlag && !isPlaying {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 6)
                            .background(Circle().foregroundColor(Color.green))
                            .frame(width: 70, height: 70)
                    } else { // when disabled
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 6)
                            .background(Circle().foregroundColor(Color.gray))
                            .frame(width: 70, height: 70)
                    }
                    
                }
                
                Spacer()
                    .frame(height: 20)
            }
            .navigationBarTitle("EchoProber")
        }
        .alert("Missing Permission", isPresented: $willAlert, actions: {
            Button("Close") {
                exit(0)
            }
        }, message: {
            Text("Please enable microphone access in Settings.")
        })
        .onAppear {
            // MARK: intialization
            do{
                printInfo(message: "Hello, echo boys.")
                audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, policy: .default, options: .defaultToSpeaker)
                
                // MARK: audio permission
                // for this we require microphone usage description in info.plist
                printInfo(message: "Request audio permission.")
                audioSession.requestRecordPermission { (status) in
                    if !status{
                        // alert
                        printInfo(message: "Audio permission missing.")
                        willAlert.toggle()
                    }
                    else{
                        // if permission granted, initialize recorder and paper
                        printInfo(message: "Audio permission granted.")
                        initRecorder()
                        initPlayer()
                    }
                }
                
                // MARK: wlan permission
                // trigger wireless data permission prompt
                client = TCPClient(address: "apple.com", port: 80)
                guard let client = client else { return }
                printInfo(message: "Request Internet permission.")
                switch client.connect(timeout: 1) {
                case .success:
                    printInfo(message: "Internet permission granted.")
                case .failure(let error):
                    printInfo(message: "Internet permission missing.")
                    print(error.localizedDescription)
                }
                
                // MARK: gyro acc mag, ori
                motionManager.deviceMotionUpdateInterval = 0.01
                motionManager.showsDeviceMovementDisplay = true
                // if you don't need calibrated magnetic field:
                // motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
                //     handle device motion updates
                // }

                // the xMagneticNorthZVertical reference frame corresponds to a device whose x axis points toward magnetic north
                motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryCorrectedZVertical, to: OperationQueue.main) { (data, error) in
                    // handle device motion updates
                    if isPlaying {
                        if timeT.isEmpty {
                            startTime = data!.timestamp
                            if data!.magneticField.accuracy.rawValue == -1 {
                                printInfo(message: "Magnetometer is not calibrated.")
                            }
                        }
                        timeT.append(data!.timestamp - startTime)
                        // unbiased rotation rate
                        gyroX.append(data!.rotationRate.x)
                        gyroY.append(data!.rotationRate.y)
                        gyroZ.append(data!.rotationRate.z)
                        // user-generated acceleration vector (without gravity)
                        accX.append(data!.userAcceleration.x)
                        accY.append(data!.userAcceleration.y)
                        accZ.append(data!.userAcceleration.z)
                        // calibrated magnetic field vector
                        // data!.magneticField.accuracy should not be -1
                        magX.append(data!.magneticField.field.x)
                        magY.append(data!.magneticField.field.y)
                        magZ.append(data!.magneticField.field.z)
                        // orientation (or attitude) relative to a reference frame
                        oriPitch.append(data!.attitude.pitch)
                        oriYaw.append(data!.attitude.yaw)
                        oriRoll.append(data!.attitude.roll)
                        // gravity vector
                        // motion.gravity.x
                        // motion.gravity.y
                        // motion.gravity.z
                        
                        // debug
                        print(data!.timestamp - startTime)
                        print(data!.rotationRate)
                        print(data!.userAcceleration)
                        // print(data!.magneticField.accuracy.rawValue)
                        print(data!.magneticField.field)
                        print(data!.attitude)
                    }
                }


                
                // MARK: gyro raw
                // raw rotation rate may be biased by other factors such as device acceleration
                motionManager.startGyroUpdates(to: motionQueue) { (data: CMGyroData?, error: Error?) in
                    guard let data = data else {
                        print("Error: \(error!)")
                        return
                    }

                    let motion: CMRotationRate = data.rotationRate
                    motionManager.gyroUpdateInterval = 0.01

                    DispatchQueue.main.async {
                        if isPlaying {
                            gyroRawX.append(motion.x)
                            gyroRawY.append(motion.y)
                            gyroRawZ.append(motion.z)
                            // debug
                            print("raw: \(motion)")
                        }
                    }
                }
                
                // MARK: acc raw
                // raw acceleration includes gravity g (9.8m/s/s)
                motionManager.startAccelerometerUpdates(to: motionQueue) { (data: CMAccelerometerData?, error: Error?) in
                    guard let data = data else {
                        print("Error: \(error!)")
                        return
                    }
                    
                    let motion: CMAcceleration = data.acceleration
                    motionManager.accelerometerUpdateInterval = 0.01
                    
                    DispatchQueue.main.async {
                        if isPlaying {
                            accRawX.append(motion.x)
                            accRawY.append(motion.y)
                            accRawZ.append(motion.z)
                            // debug
                            print("raw: \(motion)")
                        }
                    }
                }
            }
            catch{
                print(error.localizedDescription)
            }
        }
    }
    
    // MARK: connectTCP
    func connectTCP() {
        let host = hostTextField
        guard let port = Int32(portTextField) else {return}
        client = TCPClient(address: host, port: port)
        
        // as when send button pressed in the example
        guard let client = client else { return }
        printInfo(message: "Connecting.")
        switch client.connect(timeout: 1) {
        case .success:
            printInfo(message: "Connected to host \(client.address)")
            // receive upon sending
            // if let response = sendRequest(string: "GET / HTTP/1.0\n\n", using: client) {
            // appendToTextField(string: "Response: \(response)")
            // }
            connectedFlag.toggle()
        case .failure(let error):
            printInfo(message: "Connection failed: " + String(describing: error))
            print(error.localizedDescription)
        }
        
        // create listening thread
        let dispatchQueue = DispatchQueue(label: "QueueIdentification", qos: .background)
        dispatchQueue.async{
            print("Start dispatch queue.")
            // time consuming task here
            while true {
                readTCP()
            }
        }
    }
    
    // MARK: disconnectTCP
    func disconnectTCP() {
        guard let client = client else { return }
        client.close()
    }
    
    // MARK: sendTCP messageTextField
    func sendTCP() {
        guard let client = client else { return }
        switch client.send(string: messageTextField) {
        case .success:
            printInfo(message: "Text sent: \(messageTextField)")
        case .failure(let error):
            printInfo(message: "Sending failed.")
            print(error.localizedDescription)
        }
    }
    
    // MARK: sendTCP String
    func sendTCP(message: String) { // used to send strings
        guard let client = client else { return }
        switch client.send(string: message) {
        case .success:
            printInfo(message: "Text sent: \(message)")
        case .failure(let error):
            printInfo(message: "Sending failed.")
            print(error.localizedDescription)
        }
        let terminator = [UInt8]("\r\n".utf8)
        sendTCP(data: terminator) // send terminator
    }
    
    // MARK: sendTCP Data
    func sendTCP(data: Data) { // used to send Data
        guard let client = client else { return }
        switch client.send(data: data) {
        case .success:
            // printInfo(message: "Data sent: \(data.count)")
            break
        case .failure(let error):
            printInfo(message: "Sending failed.")
            print(error.localizedDescription)
        }
        let terminator = [UInt8]("\r\n".utf8)
        sendTCP(data: terminator) // send terminator
    }
    
    // MARK: sendTCP [UInt8]
    func sendTCP(data: [UInt8]) { // used to send terminator
        guard let client = client else { return }
        switch client.send(data: data) {
        case .success:
            // printInfo(message: "Data sent: \(data.count)")
            break
        case .failure(let error):
            printInfo(message: "Sending failed.")
            print(error.localizedDescription)
        }
    }
    
    // MARK: readTCP
    func readTCP() {
        guard let client = client else { return }
        guard let response = client.read(1024*10) else { return }
        if response.count < 100 {
            printInfo(message: "Text received: " + String(bytes: response, encoding: .utf8)!) // unwrapped
        } else {
            printInfo(message: "Data received: \(response.count) characters.")
            
        }
    }
    
    // MARK: initRecorder
    func initRecorder() {
        print("Entered initRecorder")
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 2, interleaved: true) // output sample rate remains the same
        guard let formatConverter =  AVAudioConverter(from: inputFormat, to: outputFormat!) else { return }
        
        // install a tap on the audio engine and specify buffer size and input format
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { (buffer, time) in
            
            if true {
                let actualBufferSize = Int(buffer.frameLength)
                printInfo(message: "Actual buffer size: \(actualBufferSize)")
                printInfo(message: "Designed buffer size: \(bufferSize)")
            }
            
            conversionQueue.async {
                
                // MARK: audioEngine thread
                // This block will be called over and over for successive buffers
                // of microphone data until you stop() AVAudioEngine
                
                let actualBufferSize = Int(buffer.frameLength)
                
                // print all data to the console
                // buffer.floatChannelData?.pointee[n] has the data for point n
                // var i = 0
                //
                // while (i < actualSampleCount) {
                //     let val = buffer.floatChannelData!.pointee[i]
                //     print("\(val)", terminator: ", ")
                //     i += 1
                // }
                // print(" ")
                
                
                // another tutorial: https://www.jianshu.com/p/9cb0914d4fed
                // on how to deal with "Wireless Data" permission prompt missing:
                // https://stackoverflow.com/questions/47382370/why-debugging-on-real-ios-devices-does-not-send-network-packets
                
                // from TensorFlow tutorial
                // AVAudioConverter is used to convert the microphone input to the format required for the model.(pcm 16)
                // let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: AVAudioFrameCount(outputFormat!.sampleRate * 2.0))
                let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: AVAudioFrameCount(actualBufferSize))

                let inputBlock: AVAudioConverterInputBlock = {inNumPackets, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buffer
                }
                
                var error: NSError? = nil

                formatConverter.convert(to: pcmBuffer!, error: &error, withInputFrom: inputBlock)
                
                // for debug. pcmBuffer = 2 * bufferSize. time interval should be 0.1s
                // printInfo(message: "\(Date().timeIntervalSince1970)")

                if error != nil {
                    print(error!.localizedDescription)
                } else {
                    let data = PCMBufferToData(PCMBuffer: pcmBuffer!)
                    sendTCP(data: data)
                }
            }
        }
        audioEngine.prepare()
    }
    
    // MARK: startRecorder
    func startRecorder() {
        print("Entered startRecorder")
        do {
            try audioEngine.start()
        }
        catch {
            print(error.localizedDescription)
        }

    }
    
    // MARK: stopRecorder
    func stopRecorder() {
        print("Entered stopRecorder")
        audioEngine.stop()
    }
    
    // MARK: initPlayer
    func initPlayer() {
        // read from wav in file
        // let sound = Bundle.main.path(forResource: "linear_chirp_100_4800_x100_hamming", ofType: "wav")
        // audioPlayer = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
        
        // read from wav in buffer
        let duration = 1600
        let nRepeats = 100
        let wavLeft = generateTone(tone_len: 100, duration: duration, repeat_num: nRepeats, f: 14000)
        let wavRight = generateChirp(chirp_len: 100, duration: duration, repeat_num: nRepeats, f0: 15000, f1: 22000)
        let wavData = generateStereoData(wavLeft: wavLeft, wavRight: wavRight, volLeft: 1.0, volRight: 1.0, duration: duration, nRepeats: nRepeats)
        
        let fileTypeString = String(AVFileType.wav.rawValue)
        audioPlayer = try! AVAudioPlayer(data: wavData, fileTypeHint: fileTypeString)
        
        printInfo(message: "[Debug] Player channels: \(audioPlayer.numberOfChannels)")
        audioPlayer.numberOfLoops = -1
        audioPlayer.prepareToPlay()
    }
    
    // MARK: startPlayer
    func startPlayer() {
        // DEBUG
        // initPlayer()
        audioPlayer.play()
    }
    
    // MARK: stopPlayer
    func stopPlayer() {
        audioPlayer.pause()
    }
    
    // MARK: startOfflineRecorder (stereo)
    func startOfflineRecorder() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let fileURL : URL
        
        if messageTextField.isEmpty || messageTextField.starts(with: "temp") {
            let date = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMdd_HHmmss"
            let time = formatter.string(from: date)
            
            messageTextField = "temp_\(time)"
            printInfo(message: "No file name. Use timestamp instead.")
        }

        fileURL = url.appendingPathComponent("\(messageTextField).pcm")
        printInfo(message: "File name: \(messageTextField).pcm")

        let settings = [
            AVFormatIDKey : Int(kAudioFormatLinearPCM), // kAudioFormatMPEG4AAC for m4a
            AVSampleRateKey : sampleRate,
            AVNumberOfChannelsKey : 2,
            AVEncoderAudioQualityKey : AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder.record()
            // debug
            print("start offline recorder")
            printDate()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: stopOfflineRecorder
    func stopOfflineRecorder() {
        audioRecorder.stop()
        // debug
        print("stop offline recorder")
        printDate()
    }
    
    // MARK: startOfflineTimer
    func startOfflineTimer() {
        // if name matches
        if messageTextField.hasPrefix("train") || messageTextField.hasPrefix("test") {
            // set timer callback functions
            pressStop = DispatchWorkItem(block: {
                if isPlaying {
                    stopOfflineRecorder()
                    saveMotionData()
                    stopPlayer()
                    printInfo(message: "Stopped.")
                    isPlaying.toggle()
                    if isTiming { // cancel scheduled task
                        pressStop.cancel()
                        pressStop = nil
                        isTiming = false
                    }
                }
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + (messageTextField.hasPrefix("train") ? 120 : 60), execute: pressStop)
            isTiming = true
        }
    }
    
    // MARK: stopOfflineTimer
    func stopOfflineTimer() {
        if isTiming { // cancel scheduled task
            pressStop.cancel()
            pressStop = nil
            isTiming = false
        }
    }
    
    // MARK: saveMotionData
    func saveMotionData() {
        // create csv
        var csvString = "Time (s),Gyro X (rad/s),Gyro Y (rad/s),Gyro Z (rad/s),Acc X (g),Acc Y (g),Acc Z (g),Mag X (uT),Mag Y (uT),Mag Z (uT),Pitch (rad),Yaw (rad),Roll (rad),GyroRaw X (rad/s),GyroRaw Y (rad/s),GyroRaw Z (rad/s),AccRaw X (g),AccRaw Y (g),AccRaw Z (g)\n"
        for i in 0..<min(timeT.count, accRawX.count, gyroRawX.count) {
            let dataString = String(format: "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n",
                                    timeT[i],
                                    gyroX[i], gyroY[i], gyroZ[i],
                                    accX[i], accY[i], accZ[i],
                                    magX[i], magY[i], magZ[i],
                                    oriPitch[i], oriYaw[i], oriRoll[i],
                                    gyroRawX[i], gyroRawY[i], gyroRawZ[i],
                                    accRawX[i], accRawY[i], accRawZ[i])
            csvString = csvString.appending(dataString)
        }

        // save csv
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL : URL
        do {
            fileURL = url.appendingPathComponent("\(messageTextField).csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("error creating file")
        }
        
        resetMotionData()
    }
    
    // MARK: resetMotionData
    func resetMotionData() {
        // debug
        printInfo(message: "[Debug] \(timeT.count) gR: \(gyroRawX.count) aR: \(accRawX.count)")
        timeT.removeAll()
        gyroX.removeAll()
        gyroY.removeAll()
        gyroZ.removeAll()
        accX.removeAll()
        accY.removeAll()
        accZ.removeAll()
        magX.removeAll()
        magY.removeAll()
        magZ.removeAll()
        oriPitch.removeAll()
        oriYaw.removeAll()
        oriRoll.removeAll()
        gyroRawX.removeAll()
        gyroRawY.removeAll()
        gyroRawZ.removeAll()
        accRawX.removeAll()
        accRawY.removeAll()
        accRawZ.removeAll()
    }
        
    // MARK: printDate
    func printDate() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        print("Time now: " + formatter.string(from: date))
    }
        
    // MARK: printInfo
    func printInfo(message: String) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "[HH:mm:ss]"
        let time = formatter.string(from: date)
        
        infoText = time + " " + message + "\n" + infoText
    }
    
    // MARK: PCM
    func PCMBufferToData(PCMBuffer: AVAudioPCMBuffer) -> Data { // convert AVAudioPCMBuffer to Data
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.int16ChannelData, count: channelCount)
        let ch0Data = Data(bytes: channels[0], count:Int(PCMBuffer.frameCapacity * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }
    
    // MARK: generateChirp
    func generateChirp(chirp_len: Int, duration: Int, repeat_num: Int, f0: Double, f1: Double) -> Array<Double> {
        let fs = 44100.0
        let t1 = Double(chirp_len) / fs;
        let t = Array(stride(from: 1.0 / fs, through: t1, by: 1.0 / fs))
        let phi = 0.0 / 360.0 // initial phase
        // generate chirp
        var chirp = [Double](repeating: 0.0, count: duration)
        for i in 0 ..< chirp_len {
            let beta = (f1-f0) / t1
            let phase = beta / 2 * t[i] * t[i] + f0 * t[i] + phi
            chirp[i] = cos(2 * Double.pi * phase)
        }
        // window chirp
        let hann = Hann(len: chirp_len)
        for i in 0 ..< chirp_len {
            chirp[i] = chirp[i] * hann[i]
        }
        // repeat chirp
        var chirpRepeat = [Double](repeating: 0.0, count: duration * repeat_num)
        for i in 0 ..< duration * repeat_num {
            chirpRepeat[i] = chirp[i % duration]
        }

        return chirpRepeat
    }
        
    // MARK: generateTone
    func generateTone(tone_len: Int, duration: Int, repeat_num: Int, f: Double) -> Array<Double> {
        let fs = 44100.0
        let t1 = Double(tone_len) / fs
        let t = Array(stride(from: 1.0 / fs, through: t1, by: 1.0 / fs))
        // generate tone
        var tone = [Double](repeating: 0.0, count: duration)
        for i in 0 ..< tone_len {
            let phase = f * t[i]
            tone[i] = cos(2 * Double.pi * phase)
        }
        // repeat tone
        var toneRepeat = [Double](repeating: 0.0, count: duration * repeat_num)
        for i in 0 ..< duration * repeat_num {
            toneRepeat[i] = tone[i % duration]
        }

        return toneRepeat
    }
    
    // MARK: Hann window
    func Hann(len: Int) -> Array<Double> {
        var window = [Double](repeating: 0.0, count: len)
        let half_len = (len % 2 == 0) ? (len / 2) : (len + 1 / 2)
        let half_window = Hann(half_len: half_len, full_len: len)
        
        for i in 0 ..< half_len {
            window[i] = half_window[i]
            window[len-i-1] = half_window[i]
        }
        
        return window
    }
    
    func Hann(half_len: Int, full_len: Int) -> Array<Double> {
        let m = Double(half_len)
        let n = Double(full_len) // same as gencoswin in MATLAB
        let t = Array(stride(from: 0.0, through: (m-1) / (n-1), by: 1.0 / (n-1)))
        var half_window = [Double](repeating: 0.0, count: half_len)
        for i in 0 ..< half_len {
            half_window[i] = 0.5 - 0.5 * cos(2 * Double.pi * t[i])
        }
        return half_window
    }
    
    // MARK: wavHeader44
    var wavHeader44 : [UInt8] = [
        0x52, 0x49, 0x46, 0x46, // “RIFF”
        // 0x24, 0xa6, 0x0e, 0x00, // if mono and duration is 4800: file size, little endian, 0x0ea624 = 960036 bytes = 960000/2 mono samples + 36 header
        // 0x24, 0x4c, 0x1d, 0x00, // if stereo and duration is 4800: 0x1d4c24 = 1920036 = 1920000/2 stereo samples + 36 holder (4800 chirp * 100 times)
        0x24, 0xc4, 0x09, 0x00, // if stereo and duration is 1600: 0x09c424 = 640036 = 640000/2 stereo samples + 36 holder (1600 chirp * 100 times)
        0x57, 0x41, 0x56, 0x45, // "WAVE"
        0x66, 0x6d, 0x74, 0x20, // "fmt "
        0x10, 0x00, 0x00, 0x00, // length of format data before, 0x10 = 16
        0x01, 0x00, 0x02, 0x00, // offset to data, 01 = PCM, 02 = stereo
        0x44, 0xac, 0x00, 0x00, // sample rate: 0x00ac44 = 44.1k
        0x88, 0x58, 0x01, 0x00, // bytes per second: 0x015888 = 88.2k (stereo)
        // 0x80, 0xbb, 0x00, 0x00, // 0x00bb80 = 48k
        // 0x00, 0xee, 0x02, 0x00, // 0x02ee00 = 192k
        0x04, 0x00, 0x10, 0x00, // 0x04 = 4 bytes (bits per sample * channels), 0x10 = 16 bits per sample (2 Int16 samples)
        0x64, 0x61, 0x74, 0x61, // "data" chunk header
        // 0x00, 0x4c, 0x1d, 0x00  // if stereo and duration is 4800: size of data section, 0x1d4c00 = 1920000 as number of samples
        0x00, 0xc4, 0x09, 0x00  // if stereo and duration is 1600: size of data section, 0x09c400 = 640000 as number of samples
        // followed by sample data
    ]
    
    typealias Byte = UInt8
    
    // MARK: int16ToBytes
    func int16ToBytes(_ value: Int16, byteArray : inout [Byte], index : Int) {
        let uintVal = UInt(bitPattern: Int(value))
        byteArray[index + 0] = UInt8(uintVal         & 0x000000ff)
        byteArray[index + 1] = UInt8((uintVal >>  8) & 0x000000ff)
    }
    
    // MARK: int32ToBytes
    func int32ToBytes(_ value: Int32, byteArray : inout [Byte], index : Int) {
        let uintVal = UInt(bitPattern: Int(value))
        byteArray[index + 0] = UInt8(uintVal         & 0x000000ff)
        byteArray[index + 1] = UInt8((uintVal >>  8) & 0x000000ff)
        byteArray[index + 2] = UInt8((uintVal >> 16) & 0x000000ff)
        byteArray[index + 3] = UInt8((uintVal >> 24) & 0x000000ff)
    }
    
    // MARK: generateStereoData
    func generateStereoData(wavLeft: [Double], wavRight: [Double], volLeft: Double, volRight: Double, duration: Int, nRepeats: Int) -> Data {
        let volumeLeft = volLeft * 32767.0 // 32767.0 = Double(Int16.max)
        let volumeRight = volRight * 32767.0
        let nSamples = duration * nRepeats
        let bytesPerSample = 2 // sample is in Int16
        let nChannels = 2
        let nBytes = nSamples * bytesPerSample * nChannels
        let wavArraySize = 44 + nBytes + 8 // what's this 8?
        var wavArray = [UInt8](repeating: 0, count: Int(wavArraySize))
        // write header
        for i in 0 ..< 44 {
            wavArray[i] = wavHeader44[i]
        }
        // re-write the data chunk size
        var nBytesUInt8 : [UInt8] = [0, 0, 0, 0]
        let nBytesInt32 = Int32(nBytes) // data size in bytes
        int32ToBytes(nBytesInt32, byteArray: &nBytesUInt8, index: 0)
        for i in 0 ..< 4 {
            wavArray[40 + i] = nBytesUInt8[i]
        }
        // load channels
        var sampleLeftBytes : [UInt8] = [0, 0]
        var sampleRightBytes : [UInt8] = [0, 0]
        for i in 0 ..< nSamples {
            let sampleLeft = wavLeft[i]
            let sampleRight = wavRight[i]
            let sampleLeftInt16 = Int16(volumeLeft * sampleLeft)
            let sampleRightInt16 = Int16(volumeRight * sampleRight)
            int16ToBytes(sampleLeftInt16, byteArray: &sampleLeftBytes, index: 0)
            int16ToBytes(sampleRightInt16, byteArray: &sampleRightBytes, index: 0)

            wavArray[44+4*i+0] = sampleRightBytes[0]
            wavArray[44+4*i+1] = sampleRightBytes[1] // stereo right
            wavArray[44+4*i+2] = sampleLeftBytes[0]
            wavArray[44+4*i+3] = sampleLeftBytes[1] // stereo left
        }
        let wavData = Data(bytes: wavArray as [UInt8], count: wavArraySize)
        return wavData
    }
    
}
