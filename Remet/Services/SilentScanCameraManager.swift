import AVFoundation
import UIKit
import Accelerate

/// Protocol for receiving scan completion events
protocol SilentScanCameraManagerDelegate: AnyObject {
    func cameraManagerDidFinishScanning(_ manager: SilentScanCameraManager, bestFrame: UIImage?)
    func cameraManagerDidUpdateProgress(_ manager: SilentScanCameraManager, progress: Double)
}

/// Camera manager for ephemeral video frame streaming
/// Privacy-focused: all captured frames are discarded immediately after selecting the best one
final class SilentScanCameraManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var isCameraReady = false

    // MARK: - Public Properties

    let session = AVCaptureSession()
    weak var delegate: SilentScanCameraManagerDelegate?

    // MARK: - Private Properties

    private var videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "com.remet.silentscan.videooutput", qos: .userInitiated)
    private var currentCameraPosition: AVCaptureDevice.Position = .back

    /// Frame buffer - cleared immediately after scan completion (privacy invariant)
    private var capturedFrames: [(image: UIImage, sharpnessScore: Float)] = []

    /// Scan timing (increased for better frame selection)
    private let scanDuration: TimeInterval = 1.5
    private var scanStartTime: Date?
    private var scanTimer: Timer?

    /// Maximum frames to buffer (prevents memory issues)
    private let maxFrameBuffer = 15

    // MARK: - Session Management

    func startSession() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        // Use photo preset for higher quality frames (matches QuickCapture quality)
        session.sessionPreset = .photo

        // Add camera input (front camera for face scanning)
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        // Configure video output for frame streaming
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Note: Don't set videoRotationAngle or isVideoMirrored here
        // We handle orientation/mirroring in imageFromSampleBuffer() for consistency
        // with how AVCapturePhotoOutput processes photos

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isCameraReady = true
            }
        }
    }

    func stopSession() {
        clearFrameBuffer()

        guard session.isRunning else { return }
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }

        DispatchQueue.main.async { [weak self] in
            self?.isCameraReady = false
        }
    }

    func flipCamera() {
        session.beginConfiguration()

        // Remove current input
        session.inputs.forEach { session.removeInput($0) }

        // Switch position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back

        // Add new input
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        // Note: Don't set mirroring - handled in imageFromSampleBuffer()

        session.commitConfiguration()
    }

    // MARK: - Scan Control

    /// Start capturing frames for the scan duration
    func startScan() {
        guard !isScanning else { return }

        // Clear any previous frames (privacy invariant)
        clearFrameBuffer()

        isScanning = true
        scanProgress = 0
        scanStartTime = Date()

        // Start progress timer
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, let startTime = self.scanStartTime else {
                timer.invalidate()
                return
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.scanDuration, 1.0)

            DispatchQueue.main.async {
                self.scanProgress = progress
                self.delegate?.cameraManagerDidUpdateProgress(self, progress: progress)
            }

            if elapsed >= self.scanDuration {
                timer.invalidate()
                self.finishScan()
            }
        }
    }

    /// Cancel the current scan and discard all frames
    func cancelScan() {
        scanTimer?.invalidate()
        scanTimer = nil
        isScanning = false
        scanProgress = 0
        scanStartTime = nil

        // Privacy invariant: clear all captured frames
        clearFrameBuffer()
    }

    // MARK: - Private Methods

    private func finishScan() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isScanning = false
            self.scanTimer = nil
            self.scanStartTime = nil

            // Select best frame by sharpness score
            let bestFrame = self.selectBestFrame()

            // Privacy invariant: clear frame buffer immediately
            self.clearFrameBuffer()

            // Notify delegate
            self.delegate?.cameraManagerDidFinishScanning(self, bestFrame: bestFrame)
        }
    }

    /// Select the frame with the highest sharpness score
    private func selectBestFrame() -> UIImage? {
        guard !capturedFrames.isEmpty else { return nil }

        return capturedFrames.max(by: { $0.sharpnessScore < $1.sharpnessScore })?.image
    }

    /// Clear all captured frames (privacy invariant enforcement)
    private func clearFrameBuffer() {
        capturedFrames.removeAll()
    }

    /// Calculate sharpness score using Laplacian variance
    private func calculateSharpness(for image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height

        // Create grayscale buffer
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return 0 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)

        // Apply Laplacian kernel and calculate variance
        var sum: Float = 0
        var sumSquared: Float = 0
        var count: Float = 0

        // Simplified Laplacian: center pixel minus average of neighbors
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let center = Float(pixels[idx])
                let neighbors = Float(pixels[idx - 1]) + Float(pixels[idx + 1]) +
                               Float(pixels[idx - width]) + Float(pixels[idx + width])
                let laplacian = center * 4 - neighbors

                sum += laplacian
                sumSquared += laplacian * laplacian
                count += 1
            }
        }

        guard count > 0 else { return 0 }

        let mean = sum / count
        let variance = (sumSquared / count) - (mean * mean)

        return variance
    }

    /// CIContext for high-quality image processing (reused for performance)
    private lazy var ciContext: CIContext = {
        CIContext(options: [.useSoftwareRenderer: false, .highQualityDownsample: true])
    }()

    /// Convert CMSampleBuffer to UIImage with proper orientation using GPU-accelerated transforms
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let bufferWidth = CVPixelBufferGetWidth(imageBuffer)
        let bufferHeight = CVPixelBufferGetHeight(imageBuffer)

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        var ciImage = CIImage(cvPixelBuffer: imageBuffer)

        // Check if buffer is in landscape (width > height) when device is in portrait
        let isBufferLandscape = bufferWidth > bufferHeight

        if isBufferLandscape {
            // Use CIImage's built-in orientation correction
            // Both cameras: rotate to portrait without mirroring
            // This matches how AVCapturePhotoOutput saves photos
            // .right = rotate 90° clockwise
            ciImage = ciImage.oriented(.right)
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension SilentScanCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Only process frames during active scan
        guard isScanning else { return }

        // Convert to UIImage
        guard let image = imageFromSampleBuffer(sampleBuffer) else { return }

        // Calculate sharpness score
        let sharpness = calculateSharpness(for: image)

        // Add to buffer (thread-safe)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScanning else { return }

            // Keep buffer size limited
            if self.capturedFrames.count >= self.maxFrameBuffer {
                // Remove lowest scoring frame
                if let minIndex = self.capturedFrames.indices.min(by: {
                    self.capturedFrames[$0].sharpnessScore < self.capturedFrames[$1].sharpnessScore
                }) {
                    self.capturedFrames.remove(at: minIndex)
                }
            }

            self.capturedFrames.append((image: image, sharpnessScore: sharpness))
        }
    }
}
