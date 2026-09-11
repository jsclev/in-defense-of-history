struct CrownOutlineCandidate: View {
    // Stroke width expressed in points at the minimum gameplay size.
    let outlinePoints: CGFloat
    private var radius: CGFloat { outlinePoints * 96 / 25.6 }
    var body: some View {
        Image("path_exit_crown")
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: 96, height: 96)
            .colorEffect(ShaderLibrary.flatExitCrown())
            .drawingGroup()
            .rotationEffect(.degrees(-20))
            .scaleEffect(x: 1, y: cos(27.5 * .pi / 180) / cos(55 * .pi / 180))
            .rotationEffect(.degrees(10))
            .frame(width: 192, height: 192)
            .drawingGroup()
            .layerEffect(ShaderLibrary.crownKeyline(.float(Float(radius)),
                .color(Color(red: 0.20, green: 0.105, blue: 0.23))),
                maxSampleOffset: CGSize(width: radius, height: radius))
    }
}
