import CoreGraphics

public struct Constants {
    public static let gameType = GameType.AIOneTurn
    public static let appIdentifier = "com.zippyzen.td"
    public static let runMode = RunMode.Debug
    public static let uiRunMode = RunMode.Replay
    public static let skin = "Upgraded"
    public static let noId = -1
    public static let minMovementCost: Double = 0.0
    public static let noScore = 0.0
    
    public static let minScale = 0.4
    public static let maxScale = CGSize(width: 512, height: 286).width / 20.0
    public static let minZoom = log2(Constants.minScale)
    public static let maxZoom = log2(Constants.maxScale)
    
    public static let debugModeKey = "debugMode"
    public static let showDebugLayoutGuidesKey = "showSafeAreaOverlay"
    public static let rubberBandClampCoefficient: CGFloat = 0.3
    public static let mapMomentumPanDecelerationConstant: CGFloat = 0.996
    public static let mapMomentumPanSpringMass: CGFloat = 22
    
    public static let mapMomentumScaleDecelerationConstant: CGFloat = 0.985
    public static let mapMomentumScaleSpringMass: CGFloat = 25
    
    public static let mapMomentumScaleGestureMaxTimeDifference = 0.15
}
