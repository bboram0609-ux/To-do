import SwiftUI

enum KongiFace: String, CaseIterable, Codable {
    case normal, happy, sparkle, calm, sleepy
}

enum KongiProp: String, Codable {
    case none, star, heart, breath, water, zzz
}

enum KongiStage: Int, CaseIterable, Codable {
    case seed = 0, sprout, twoLeaves, flower

    /// 단계에 오르는 데 필요한 포인트 (예시 값, 직접 써 보며 조정)
    var threshold: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 100
        case .twoLeaves: return 500
        case .flower: return 1500
        }
    }

    var title: String {
        switch self {
        case .seed: return "씨앗"
        case .sprout: return "새싹"
        case .twoLeaves: return "두 잎"
        case .flower: return "꽃"
        }
    }

    var next: KongiStage? { KongiStage(rawValue: rawValue + 1) }

    static func forPoints(_ points: Int) -> KongiStage {
        KongiStage.allCases.last { points >= $0.threshold } ?? .seed
    }
}

/// 콩이 캐릭터. 200x200 좌표계로 그린 뒤 주어진 크기에 맞춰 늘린다.
/// 캐릭터를 다른 그림으로 바꿀 때는 이 파일만 교체하면 된다.
struct KongiView: View {
    var stage: KongiStage = .twoLeaves
    var face: KongiFace = .normal
    var prop: KongiProp = .none

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width, size.height) / 200
            ctx.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 200 * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)
            KongiDrawing.draw(&ctx, stage: stage, face: face, prop: prop)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("콩이, \(stage.title)")
    }
}

enum KongiDrawing {
    private typealias C = KongiColors

    static func draw(_ ctx: inout GraphicsContext, stage: KongiStage, face: KongiFace, prop: KongiProp) {
        // 그림자
        ctx.fill(ellipse(100, 182, 46, 7), with: .color(C.beanEdge.opacity(0.18)))

        // 발
        for x: CGFloat in [84, 116] {
            fillStroke(&ctx, ellipse(x, 173, 13, 7), fill: C.bean, stroke: C.beanEdge, width: 3)
        }

        // 팔 (기쁠 때는 위로)
        if face == .happy || face == .sparkle {
            fillStroke(&ctx, ellipse(48, 98, 9, 15, rotation: -35), fill: C.bean, stroke: C.beanEdge, width: 3)
            fillStroke(&ctx, ellipse(152, 98, 9, 15, rotation: 35), fill: C.bean, stroke: C.beanEdge, width: 3)
        } else {
            fillStroke(&ctx, ellipse(51, 132, 9, 15, rotation: 22), fill: C.bean, stroke: C.beanEdge, width: 3)
            fillStroke(&ctx, ellipse(149, 132, 9, 15, rotation: -22), fill: C.bean, stroke: C.beanEdge, width: 3)
        }

        // 몸통
        var body = Path()
        body.move(to: p(100, 52))
        body.addCurve(to: p(153, 124), control1: p(143, 52), control2: p(157, 92))
        body.addCurve(to: p(100, 172), control1: p(149, 158), control2: p(127, 172))
        body.addCurve(to: p(47, 124), control1: p(73, 172), control2: p(51, 158))
        body.addCurve(to: p(100, 52), control1: p(43, 92), control2: p(57, 52))
        body.closeSubpath()
        fillStroke(&ctx, body, fill: C.bean, stroke: C.beanEdge, width: 3.5)
        ctx.fill(ellipse(100, 140, 30, 22), with: .color(C.belly))
        ctx.stroke(quad(68, 76, 76, 66, 88, 64), with: .color(Color.white.opacity(0.6)), style: round(4))

        // 볼
        ctx.fill(ellipse(72, 123, 9, 6), with: .color(C.cheek.opacity(0.75)))
        ctx.fill(ellipse(128, 123, 9, 6), with: .color(C.cheek.opacity(0.75)))

        drawEyes(&ctx, face: face)
        drawMouth(&ctx, face: face)
        drawSprout(&ctx, stage: stage)
        drawProp(&ctx, prop: prop)
    }

    private static func drawEyes(_ ctx: inout GraphicsContext, face: KongiFace) {
        let eye = GraphicsContext.Shading.color(C.eye)
        switch face {
        case .happy:
            ctx.stroke(quad(75, 111, 82, 101, 89, 111), with: eye, style: round(3.5))
            ctx.stroke(quad(111, 111, 118, 101, 125, 111), with: eye, style: round(3.5))
        case .calm:
            ctx.stroke(quad(75, 107, 82, 114, 89, 107), with: eye, style: round(3.5))
            ctx.stroke(quad(111, 107, 118, 114, 125, 107), with: eye, style: round(3.5))
        case .sleepy:
            ctx.stroke(line(75, 110, 89, 110), with: eye, style: round(3.5))
            ctx.stroke(line(111, 110, 125, 110), with: eye, style: round(3.5))
        case .normal, .sparkle:
            let r: CGFloat = face == .sparkle ? 7.5 : 5.8
            ctx.fill(ellipse(82, 107, r, r), with: eye)
            ctx.fill(ellipse(118, 107, r, r), with: eye)
            ctx.fill(ellipse(84.5, 104.5, 2, 2), with: .color(.white))
            ctx.fill(ellipse(120.5, 104.5, 2, 2), with: .color(.white))
            if face == .sparkle {
                ctx.fill(ellipse(79.5, 110, 1.2, 1.2), with: .color(.white))
                ctx.fill(ellipse(115.5, 110, 1.2, 1.2), with: .color(.white))
            }
        }
    }

    private static func drawMouth(_ ctx: inout GraphicsContext, face: KongiFace) {
        switch face {
        case .happy, .sparkle:
            var mouth = quad(91, 121, 100, 136, 109, 121)
            mouth.closeSubpath()
            fillStroke(&ctx, mouth, fill: C.mouth, stroke: C.eye, width: 2.5)
        case .calm:
            ctx.fill(ellipse(100, 126, 3.5, 4), with: .color(C.eye))
        case .sleepy:
            ctx.fill(ellipse(100, 126, 2.5, 2), with: .color(C.eye))
        case .normal:
            ctx.stroke(quad(93, 122, 100, 130, 107, 122), with: .color(C.eye), style: round(3))
        }
    }

    private static func drawSprout(_ ctx: inout GraphicsContext, stage: KongiStage) {
        let stem = GraphicsContext.Shading.color(C.leafDark)
        if stage == .seed {
            ctx.stroke(quad(100, 53, 97, 46, 102, 43), with: stem, style: round(4))
            return
        }
        ctx.stroke(quad(100, 53, 97, 41, 101, 29), with: stem, style: round(4))

        var right = quad(101, 35, 117, 19, 132, 27)
        right.addQuadCurve(to: p(101, 35), control: p(119, 43))
        fillStroke(&ctx, right, fill: C.leaf, stroke: C.leafDark, width: 2.5)

        if stage.rawValue >= KongiStage.twoLeaves.rawValue {
            var left = quad(99, 41, 83, 25, 68, 33)
            left.addQuadCurve(to: p(99, 41), control: p(81, 49))
            fillStroke(&ctx, left, fill: C.leaf, stroke: C.leafDark, width: 2.5)
        }
        if stage == .flower {
            for i in 0..<5 {
                let a = Double(i) / 5 * 2 * .pi - .pi / 2
                let cx = 101 + CGFloat(cos(a)) * 8
                let cy = 21 + CGFloat(sin(a)) * 8
                fillStroke(&ctx, ellipse(cx, cy, 6.5, 6.5), fill: C.petal, stroke: C.beanEdge, width: 1.5)
            }
            ctx.fill(ellipse(101, 21, 5, 5), with: .color(C.pollen))
        }
    }

    private static func drawProp(_ ctx: inout GraphicsContext, prop: KongiProp) {
        switch prop {
        case .none:
            break
        case .water:
            var glass = Path()
            glass.move(to: p(152, 110)); glass.addLine(to: p(178, 110))
            glass.addLine(to: p(174, 148)); glass.addLine(to: p(156, 148)); glass.closeSubpath()
            fillStroke(&ctx, glass, fill: C.glass, stroke: C.beanEdge, width: 2.5)
            var water = Path()
            water.move(to: p(153.6, 124)); water.addLine(to: p(176.4, 124))
            water.addLine(to: p(174, 148)); water.addLine(to: p(156, 148)); water.closeSubpath()
            ctx.fill(water, with: .color(C.water))
        case .heart:
            var heart = Path()
            heart.move(to: p(160, 64))
            heart.addCurve(to: p(148, 61), control1: p(160, 55), control2: p(148, 53))
            heart.addCurve(to: p(160, 79), control1: p(148, 69), control2: p(160, 75))
            heart.addCurve(to: p(172, 61), control1: p(160, 75), control2: p(172, 69))
            heart.addCurve(to: p(160, 64), control1: p(172, 53), control2: p(160, 55))
            heart.closeSubpath()
            fillStroke(&ctx, heart, fill: C.cheek, stroke: C.mouth, width: 2)
        case .breath:
            let shade = GraphicsContext.Shading.color(C.leafDark.opacity(0.55))
            ctx.stroke(ellipse(150, 74, 5, 5), with: shade, lineWidth: 2.5)
            ctx.stroke(ellipse(163, 58, 7.5, 7.5), with: shade, lineWidth: 2.5)
            ctx.stroke(ellipse(180, 38, 10, 10), with: shade, lineWidth: 2.5)
        case .zzz:
            let sizes: [(CGFloat, CGFloat, CGFloat)] = [(150, 68, 16), (162, 50, 21), (177, 30, 27)]
            for (x, y, size) in sizes {
                ctx.draw(
                    Text("z").font(.system(size: size, weight: .heavy, design: .rounded)).foregroundColor(C.beanEdge),
                    at: p(x, y)
                )
            }
        case .star:
            let pts: [CGPoint] = [
                p(162, 48), p(166, 58), p(177, 59), p(169, 66), p(171, 77),
                p(162, 71), p(153, 77), p(155, 66), p(147, 59), p(158, 58)
            ]
            var star = Path()
            star.addLines(pts)
            star.closeSubpath()
            fillStroke(&ctx, star, fill: C.pollen, stroke: C.beanEdge, width: 2)
        }
    }

    // MARK: - 도형 도우미

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static func round(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation degrees: CGFloat = 0) -> Path {
        let path = Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        guard degrees != 0 else { return path }
        let t = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -cx, y: -cy)
        return path.applying(t)
    }

    private static func quad(_ x0: CGFloat, _ y0: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(x0, y0))
        path.addQuadCurve(to: p(x1, y1), control: p(cx, cy))
        return path
    }

    private static func line(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(x0, y0))
        path.addLine(to: p(x1, y1))
        return path
    }

    private static func fillStroke(_ ctx: inout GraphicsContext, _ path: Path, fill: Color, stroke: Color, width: CGFloat) {
        ctx.fill(path, with: .color(fill))
        ctx.stroke(path, with: .color(stroke), style: round(width))
    }
}

#Preview {
    HStack {
        KongiView(stage: .seed)
        KongiView(stage: .sprout, face: .happy, prop: .star)
        KongiView(stage: .flower, face: .sparkle, prop: .heart)
    }
    .padding()
}
