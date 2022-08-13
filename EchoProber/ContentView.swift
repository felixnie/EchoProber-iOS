//
//  ContentView.swift
//  EchoProber
//
//  Created by Hongtuo on 2/8/22.
//

import SwiftUI
import AVKit
import SwiftSocket

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
    // for system
    @State var infoText = ""
    @State var playingFlag = false
    @State var alertFlag = false
    @State var audioSession : AVAudioSession!
    
    // for recorder
    var audioEngine : AVAudioEngine = AVAudioEngine()
    let conversionQueue = DispatchQueue(label: "conversionQueue")
    let sampleRate = 48000
    let bufferSize = 4800 // different from actual sample count
    
    // for player
    @State var audioPlayer : AVAudioPlayer!
    
    // for socket
    @AppStorage("host") var hostTextField = "10.25.213.103"
    @AppStorage("port") var portTextField = "8173"
    @State var connectedFlag = false
    @State var messageTextField = ""
    
    @State var client : TCPClient?
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
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
                        
                        
                        if playingFlag {
                            // same as the actions of pressing stop button
                            self.stopRecorder()
                            self.stopPlayer()
                            printInfo(message: "Stopped.")
                            self.playingFlag.toggle()
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
                
                // MARK: send text
                HStack() {
                    Text("TEXT")
                        .font(.headline)
                        .bold()
                    TextField("Text Message", text: $messageTextField)
                        .textFieldStyle(.roundedBorder)
                    Button("Send", action: {
                        sendTCP()
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
                Text(self.infoText)
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
                
                // MARK: play button
                Button(action: {
                    
                    // button behavior
                    if playingFlag { // stop actions
                        self.stopRecorder()
                        self.stopPlayer()
                        printInfo(message: "Stopped.")
                        self.playingFlag.toggle()
                    } else {
                        self.startRecorder()
                        self.startPlayer()
                        printInfo(message: "Started.")
                        self.playingFlag.toggle()
                    }
                    
                }) {
                    // button style
                    if connectedFlag && playingFlag { // stop actions
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 6)
                            .background(Circle().foregroundColor(Color.red))
                            .frame(width: 70, height: 70)
                    } else if connectedFlag && !playingFlag {
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
                    
                }.disabled(!connectedFlag)
                
                Spacer()
                    .frame(height: 20)
            }
            .navigationBarTitle("EchoProber")
        }
        .alert("Missing Permission", isPresented: self.$alertFlag, actions: {
            Button("Close") {
                exit(0)
            }
        }, message: {
            Text("Please enable microphone access in Settings.")
        })
        .onAppear {
            
            do{
                // MARK: intialization
                printInfo(message: "Hello, echo boys.")
                self.audioSession = AVAudioSession.sharedInstance()
                try self.audioSession.setCategory(.playAndRecord, mode: .default, policy: .default, options: .defaultToSpeaker)
                
                // request audio permission
                // for this we require microphone usage description in info.plist
                printInfo(message: "Request audio permission.")
                self.audioSession.requestRecordPermission { (status) in
                    if !status{
                        // alert
                        printInfo(message: "Audio permission missing.")
                        self.alertFlag.toggle()
                    }
                    else{
                        // if permission granted, initialize recorder and paper
                        printInfo(message: "Audio permission granted.")
                        // self.getAudios()
                        self.initRecorder()
                        self.initPlayer()
                    }
                }
                
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
            }
            catch{
                
                print(error.localizedDescription)
                
            }
        }
    }
    
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
    
    func disconnectTCP() {
        guard let client = client else { return }
        client.close()
    }
    
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
    
    func readTCP() {
        guard let client = client else { return }
        guard let response = client.read(1024*10) else { return }
        printInfo(message: String(bytes: response, encoding: .utf8)!) // unwrapped
    }
    
    func initRecorder() {
        print("Entered initRecorder")
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: false) // output sample rate remains the same
        guard let formatConverter =  AVAudioConverter(from: inputFormat, to: outputFormat!) else { return }
        
        // install a tap on the audio engine and specify buffer size and input format
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { (buffer, time) in
            
            let actualBufferSize = Int(buffer.frameLength)
            printInfo(message: "Actual buffer size: \(actualBufferSize)")
            printInfo(message: "Designed buffer size: \(bufferSize)")
            
            self.conversionQueue.async {
                
                // MARK: audio data thread
                // This block will be called over and over for successive buffers
                // of microphone data until you stop() AVAudioEngine
                
                let actualBufferSize = Int(buffer.frameLength)
                print("    Actual buffer size: \(actualBufferSize)")
                print("    Designed buffer size: \(bufferSize)")
                
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
                
//                let data = Data(buffer: UnsafeBufferPointer(start: buffer.int16ChannelData, count: Int(buffer.frameLength)))
//                guard let client = client else { return }
//                switch client.send(data: data) {
//                case .success:
//                    printInfo(message: "Data sent successfully.")
//                case .failure(let error):
//                    printInfo(message: "Sending failed." + String(describing: error))
//                }
                
                // another tutorial: https://www.jianshu.com/p/9cb0914d4fed
                // on how to deal with "Wireless Data" permission prompt missing:
                // https://stackoverflow.com/questions/47382370/why-debugging-on-real-ios-devices-does-not-send-network-packets
                
                // from TensorFlow tutorial
                // AVAudioConverter is used to convert the microphone input to the format required for the model.(pcm 16)
                // let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: AVAudioFrameCount(outputFormat!.sampleRate * 2.0))
                let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: AVAudioFrameCount(actualBufferSize))
//                var error: NSError? = nil
//
                let inputBlock: AVAudioConverterInputBlock = {inNumPackets, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buffer
                }
                
                var error: NSError? = nil

                formatConverter.convert(to: pcmBuffer!, error: &error, withInputFrom: inputBlock)
                
                // for debug. pcmBuffer = 2 * bufferSize. time interval should be 0.1s
                // printInfo(message: "\(String(describing: pcmBuffer)) \(Date().timeIntervalSince1970)")
                printInfo(message: "\(Date().timeIntervalSince1970)")

                if error != nil {
                    print(error!.localizedDescription)
                } else {
                    // \r is "Carriage Return" (CR, ASCII character 13), \n is "Line Feed" (LF, ASCII character 10)
                    let terminator = [UInt8]("\r\n".utf8)
                    
                    let data = toData(PCMBuffer: pcmBuffer!)
                    
                    // var data = toData(PCMBuffer: pcmBuffer!)
                    // withUnsafeBytes(of: terminator) { data.append(contentsOf: $0) }

                    // let data = bufferData.append(contentsOf: terminator)
                    
                    // send data
                    guard let client = client else { return }
                    switch client.send(data: data) {
                    case .success:
                        printInfo(message: "Data sent: \(data.count)")
                    case .failure(let error):
                        printInfo(message: "Sending failed.")
                        print(error.localizedDescription)
                    }
                    switch client.send(data: terminator) {
                    case .success:
                        printInfo(message: "Data sent: \(terminator.count)")
                    case .failure(let error):
                        printInfo(message: "Sending failed.")
                        print(error.localizedDescription)
                    }

                }
                
//                else if let channelData = pcmBuffer!.int16ChannelData {
//
//                    let channelDataValue = channelData.pointee
//                    let channelDataValueArray = stride(from: 0,
//                                                       to: Int(pcmBuffer!.frameLength),
//                                                       by: buffer.stride).map{ channelDataValue[$0] }
//
//                    // Converted pcm 16 values are delegated to the controller.
//                    // self.delegate?.didOutput(channelData: channelDataValueArray)
//                    print("count of channelDataValueArray is \(channelDataValueArray.count)")
//                    print("value of channelDataValue is \(channelDataValue)")
//                    print("value of Int(pcmBuffer!.frameLength) is \(Int(pcmBuffer!.frameLength))")
//                    printDate()
//                }
            }
        }
        audioEngine.prepare()
    }
    
    func startRecorder() {
        print("Entered startRecorder")
        do {
            try audioEngine.start()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func stopRecorder() {
        print("Entered stopRecorder")
        audioEngine.stop()
    }
    
    func initPlayer() {
        let sound = Bundle.main.path(forResource: "linear_chirp_500_4410_x100", ofType: "wav")
        self.audioPlayer = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
        self.audioPlayer.numberOfLoops = -1
        self.audioPlayer.prepareToPlay()
    }
    
    func startPlayer() {
        self.audioPlayer.play()
    }
    
    func stopPlayer() {
        self.audioPlayer.pause()
    }
    
    func printDate() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSSS"
        print("Time now: " + formatter.string(from: date))
    }
    
    func generateSound() -> Array<Double> {
        /*
        fs = 44100;
        t = 1/fs:1/fs:500/fs;
        f0 = 15000;
        t1 = 500/fs;
        f1 = 20000;
        linear_chirp = chirp(t, f0, t1, f1);

        p = 1;
        phi = 0;
        beta = (f1-f0).*(t1.^(-p));
        yvalue = cos(2*pi*(beta./(1+p)*(t.^(1+p))+f0*t+phi/360));
        */
        let fs = 44100.0
        let phi = 0.0 // phase
        let t = Array(stride(from: 1.0 / fs, through: 500.0 / fs, by: 1.0 / fs))
        let f0 = 15000.0;
        let t1 = 500.0 / fs;
        let f1 = 20000.0;
        var sound = [Double](repeating: 0.0, count: 4410)
        
        for i in 0..<t.count {
            let beta = (f1-f0) / t1
            sound[i] = cos(2 * Double.pi * (beta / 2 * t[i] * t[i] + f0 * t[i] + phi / 360.0))
        }
        
        return sound
    }
    
    func printInfo(message: String) {
        let showTime = true
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        let time = formatter.string(from: date)
        
        if(showTime) {
            self.infoText = time + " " + message + "\n" + self.infoText
        } else{
            self.infoText = message + "\n" + self.infoText
        }
        
    }
    
    func toNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData { // convert AVAudioPCMBuffer to NSData
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.int16ChannelData, count: channelCount)
        let ch0Data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameCapacity * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }
    
    func toData(PCMBuffer: AVAudioPCMBuffer) -> Data { // convert AVAudioPCMBuffer to Data
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.int16ChannelData, count: channelCount)
        let ch0Data = Data(bytes: channels[0], count:Int(PCMBuffer.frameCapacity * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }
    
}

extension Data { // convert array to Data

    init<T>(fromArray values: [T]) {
        self = values.withUnsafeBytes { Data($0) }
    }

    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = Array<T>(repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }
}

