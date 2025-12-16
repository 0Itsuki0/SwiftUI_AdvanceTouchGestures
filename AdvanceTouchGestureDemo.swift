
import SwiftUI

struct AdvanceTouchGestureDemo: View {
    
    @State private var touches: Array<ProcessedTouch> = []
    @State private var event: UIEvent? = nil
    
    // whether 3D Touch is available or not
    private let `3DTouchAvailable` = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.traitCollection.forceTouchCapability == .available

    var body: some View {

        NavigationStack {

            ZStack {
                self.touchesView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.yellow.opacity(0.1))
            .gesture(
                TouchesGestureRecognizer(
                    touches: $touches,
                    event: $event
                )
            )
            .navigationTitle("Touch Inputs + 0.1")
            .safeAreaInset(edge: .leading, alignment: .top, content: {
                Text("Type, Force, Angle, Predictions and more!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            })
        }

    }
    
    @ViewBuilder
    private func touchesView() -> some View {
        let touches = Array(self.touches)
        ForEach(0..<touches.count, id:\.self) { index in
            let touch: ProcessedTouch = touches[index]
            Group {
                Circle()
                    .fill(.blue.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .overlay(alignment: .top, content: {
                        self.touchInfo(touch)
                            .padding(.top, 16)
                            .fixedSize()
                    })
                    .position(touch.location)

                if let previousLocation = touch.previousLocation {
                    Circle()
                        .fill(.red.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .position(previousLocation)
                }

                ForEach(0..<touch.predictedLocations.count, id: \.self) { index in
                    let predictedLocation: CGPoint = touch.predictedLocations[index]
                    Text("▲")
                        .font(.headline)
                        .foregroundStyle(.blue.opacity(0.3))
                        .position(predictedLocation)

                }
            }

        }
    }
    
    @ViewBuilder
    private func touchInfo(_ touch: ProcessedTouch) -> some View {
        VStack(alignment: .leading, content: {
            self.row("Touch Type", right: touch.touchType.stringRepresentable)
            self.row("Location", right: "(\(touch.location.x.twoDecimal), \(touch.location.y.twoDecimal))")
            self.row("Force", right: self.`3DTouchAvailable` ? touch.force.twoDecimal : "(3D Touch not available)")
            self.row("Altitude Angle", right: "\(touch.altitudeAngle.twoDecimal) rad")
            self.row("Azimuth Angle", right: "\(touch.azimuthAngle.twoDecimal) rad")
            self.row("Roll Angle", right: touch.touchType != .pencil ? "(Not supported)" : "\(touch.rollAngle.twoDecimal) rad")
        })
    }
    
    @ViewBuilder
    private func row(_ left: String, right: String) -> some View {
        HStack(spacing: 8) {
            Text(left)
                .font(.headline)
            Spacer()
            Text(right)
                .foregroundStyle(.secondary)
        }
    }
}

extension UITouch.TouchType {
    var stringRepresentable: String {
        switch self {
            
        case .direct:
            "Finger"
        case .pencil:
            "Pencil"
        default:
            "Others"
        }
    }
}

extension CGFloat {
    var twoDecimal: String {
        let float = Float(self)
        return float.formatted(.number.precision(.fractionLength(2)))
    }
}

// for triggering view update
struct ProcessedTouch: Identifiable, Hashable {
    let id: UUID = UUID()

    var touchType: UITouch.TouchType
    
    var location: CGPoint
    var previousLocation: CGPoint?
    var predictedLocations: [CGPoint]
    
    var majorRadius: CGFloat
    
    var force: CGFloat
    
    var altitudeAngle: CGFloat
    // It is more expensive to get the azimuth angle (as opposed to the azimuth unit vector), but it can also be more convenient
    var azimuthAngle: CGFloat
    var rollAngle: CGFloat
    
    init(
        touch: UITouch,
        event: UIEvent?,
        coordinateConverter: UIGestureRecognizerRepresentable.CoordinateSpaceConverter
    ) {
        self.touchType = touch.type
        self.location = coordinateConverter.convert(globalPoint: touch.preciseLocation(in: touch.view), to: .local)
        self.previousLocation = coordinateConverter.convert(globalPoint: touch.preciseLocation(in: touch.view), to: .local)
        let predictions = event?.predictedTouches(for: touch) ?? []
        self.predictedLocations = predictions.map({
            coordinateConverter.convert(globalPoint: $0.preciseLocation(in: $0.view), to: .local)
        })
        
        self.majorRadius = touch.majorRadius
        
        self.force = touch.force
        self.altitudeAngle = touch.altitudeAngle
        self.azimuthAngle = touch.azimuthAngle(in: touch.view)
        self.rollAngle = touch.rollAngle

    }

}


struct TouchesGestureRecognizer: UIGestureRecognizerRepresentable {
        
    @Binding var touches: Array<ProcessedTouch>
    @Binding var event: UIEvent?

    func makeUIGestureRecognizer(context: Context) -> UITouchesGestureRecognizer {
        let gesture = UITouchesGestureRecognizer()
        gesture.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber,   UITouch.TouchType.pencil.rawValue as NSNumber]
        gesture.cancelsTouchesInView = false
        return gesture
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UITouchesGestureRecognizer, context: Context) {
        DispatchQueue.main.async(execute: {
            self.touches = recognizer.touches.map({
                ProcessedTouch(touch: $0, event: recognizer.event, coordinateConverter: context.converter)
            })
            self.event = recognizer.event
        })
    }

}

class UITouchesGestureRecognizer: UIGestureRecognizer {
    var touches: Set<UITouch> = []
    var event: UIEvent?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.touches.isEmpty {
            self.state = .began
        }
        self.touches.formUnion(touches)
        self.event = event
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        self.event = event
        self.touches.formUnion(touches)
        self.state = .changed
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        self.event = event
        self.touches.subtract(touches)
        if self.touches.isEmpty {
            self.state = .cancelled
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        self.event = event
        self.touches.subtract(touches)
        if self.touches.isEmpty {
            self.state = .ended
        }
    }
    
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        self.touches.formUnion(touches)
    }
    
    override func reset() {
        self.event = nil
        self.touches.removeAll()
    }
}



