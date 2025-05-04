//
//  Notchly+LogoShape.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//

import SwiftUI

/// The vector shape for the Notchly logo.
/// Converted from PaintCode, this shape includes mirrored strokes and scaling logic
/// so that the design can fit cleanly into any SwiftUI frame.
struct NotchlyLogoShape: Shape {
    func path(in rect: CGRect) -> Path {

        // MARK: - PaintCode Bounds
        let originalMinX: CGFloat = 276.27
        let originalMaxX: CGFloat = 722.28
        let originalMinY: CGFloat = 244.01
        let originalMaxY: CGFloat = 780.95

        let width  = originalMaxX - originalMinX
        let height = originalMaxY - originalMinY

        // MARK: - Scale + Center Transform
        let scale = min(rect.width / width, rect.height / height)

        let dx = rect.midX - (originalMinX + width / 2) * scale
        let dy = rect.midY - (originalMinY + height / 2) * scale

        /// PaintCode helper: mirrored X from center of original bounds
        func S(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let mx = originalMinX + originalMaxX - x
            return CGPoint(x: mx * scale + dx, y: y * scale + dy)
        }

        // MARK: - Path Drawing
        var p = Path()

        /// —— Stroke 1
        p.move(to: S(276.27, 439.06))
        p.addLine(to: S(276.23, 467.92))
        p.addLine(to: S(276.19, 491.71))
        p.addLine(to: S(276.14, 521.96))
        p.addLine(to: S(276.07, 556.68))
        p.addLine(to: S(276.03, 586.21))
        p.addLine(to: S(276.00, 650.97))
        p.addCurve(
            to: S(276.28, 688.48),
            control1: S(276.00, 650.97),
            control2: S(276.11, 686.58)
        )
        p.addCurve(
            to: S(281.30, 710.85),
            control1: S(277.02, 696.47),
            control2: S(279.12, 705.76)
        )
        p.addCurve(
            to: S(296.28, 735.38),
            control1: S(285.19, 719.95),
            control2: S(290.21, 728.09)
        )
        p.addCurve(
            to: S(318.57, 755.52),
            control1: S(302.61, 742.98),
            control2: S(310.07, 749.65)
        )
        p.addCurve(
            to: S(361.73, 771.49),
            control1: S(331.71, 764.59),
            control2: S(346.08, 769.31)
        )
        p.addCurve(
            to: S(388.55, 771.69),
            control1: S(370.87, 772.76),
            control2: S(379.82, 772.83)
        )
        p.addCurve(
            to: S(419.69, 762.09),
            control1: S(399.28, 770.29),
            control2: S(409.67, 767.08)
        )
        p.addCurve(
            to: S(446.68, 742.77),
            control1: S(429.90, 757.01),
            control2: S(438.95, 750.59)
        )
        p.addCurve(
            to: S(463.32, 719.95),
            control1: S(453.19, 736.18),
            control2: S(458.77, 728.59)
        )
        p.addCurve(
            to: S(476.11, 696.02),
            control1: S(467.53, 711.95),
            control2: S(471.81, 703.98)
        )
        p.addCurve(
            to: S(491.48, 667.74),
            control1: S(481.21, 686.58),
            control2: S(491.48, 667.74)
        )
        p.addLine(to: S(510.47, 632.83))
        p.addLine(to: S(536.16, 585.65))
        p.addLine(to: S(560.33, 541.00))
        p.addLine(to: S(593.20, 480.62))
        p.addCurve(
            to: S(608.45, 452.73),
            control1: S(593.20, 480.62),
            control2: S(603.49, 462.09)
        )
        p.addCurve(
            to: S(601.35, 428.19),
            control1: S(612.90, 444.33),
            control2: S(609.66, 432.71)
        )
        p.addCurve(
            to: S(574.49, 434.58),
            control1: S(591.32, 422.74),
            control2: S(580.63, 424.72)
        )
        p.addCurve(
            to: S(557.15, 466.10),
            control1: S(568.17, 444.75),
            control2: S(557.15, 466.10)
        )
        p.addLine(to: S(527.88, 519.46))
        p.addLine(to: S(514.94, 544.38))
        p.addLine(to: S(499.28, 572.45))
        p.addLine(to: S(491.28, 587.48))
        p.addLine(to: S(481.58, 605.92))
        p.addLine(to: S(469.55, 626.15))
        p.addLine(to: S(458.10, 648.78))
        p.addLine(to: S(446.51, 670.46))
        p.addLine(to: S(433.63, 693.50))
        p.addCurve(
            to: S(419.71, 715.19),
            control1: S(433.63, 693.50),
            control2: S(425.51, 709.05)
        )
        p.addCurve(
            to: S(391.05, 731.45),
            control1: S(412.07, 723.28),
            control2: S(402.25, 729.19)
        )
        p.addCurve(
            to: S(351.89, 729.51),
            control1: S(377.93, 734.10),
            control2: S(364.71, 734.06)
        )
        p.addCurve(
            to: S(325.88, 710.40),
            control1: S(341.35, 725.77),
            control2: S(333.05, 719.49)
        )
        p.addCurve(
            to: S(313.11, 670.46),
            control1: S(316.35, 698.33),
            control2: S(313.10, 685.22)
        )
        p.addCurve(
            to: S(313.14, 592.05),
            control1: S(313.13, 644.33),
            control2: S(313.14, 592.05)
        )
        p.addLine(to: S(313.15, 569.58))
        p.addLine(to: S(313.16, 535.05))
        p.addLine(to: S(313.16, 516.38))
        p.addLine(to: S(313.16, 477.83))
        p.addLine(to: S(313.17, 441.90))
        p.addLine(to: S(313.18, 379.23))
        p.addLine(to: S(313.19, 360.90))
        p.addLine(to: S(313.19, 346.41))
        p.addCurve(
            to: S(313.21, 314.63),
            control1: S(313.19, 346.41),
            control2: S(313.20, 328.05)
        )
        p.addCurve(
            to: S(313.22, 292.73),
            control1: S(313.21, 301.20),
            control2: S(313.21, 305.00)
        )
        p.addCurve(
            to: S(313.23, 265.54),
            control1: S(313.22, 280.45),
            control2: S(313.23, 274.60)
        )
        p.addCurve(
            to: S(312.58, 259.42),
            control1: S(313.24, 256.48),
            control2: S(313.02, 261.33)
        )
        p.addCurve(
            to: S(311.27, 255.46),
            control1: S(312.14, 257.50),
            control2: S(311.82, 256.70)
        )
        p.addCurve(
            to: S(308.60, 251.13),
            control1: S(310.71, 254.21),
            control2: S(309.68, 252.43)
        )
        p.addCurve(
            to: S(306.63, 249.08),
            control1: S(307.53, 249.82),
            control2: S(307.35, 249.72)
        )
        p.addCurve(
            to: S(304.19, 247.24),
            control1: S(305.92, 248.44),
            control2: S(305.07, 247.80)
        )
        p.addCurve(
            to: S(301.89, 245.97),
            control1: S(303.31, 246.68),
            control2: S(302.70, 246.35)
        )
        p.addCurve(
            to: S(299.58, 245.03),
            control1: S(301.08, 245.58),
            control2: S(300.36, 245.29)
        )
        p.addCurve(
            to: S(295.92, 244.17),
            control1: S(298.80, 244.77),
            control2: S(297.15, 244.34)
        )
        p.addCurve(
            to: S(293.91, 244.01),
            control1: S(294.69, 244.00),
            control2: S(294.58, 244.03)
        )
        p.addCurve(
            to: S(292.25, 244.04),
            control1: S(293.24, 243.99),
            control2: S(292.81, 244.00)
        )
        p.addCurve(
            to: S(289.92, 244.33),
            control1: S(291.70, 244.07),
            control2: S(290.70, 244.18)
        )
        p.addCurve(
            to: S(287.15, 245.09),
            control1: S(289.15, 244.48),
            control2: S(288.06, 244.77)
        )
        p.addCurve(
            to: S(285.30, 245.88),
            control1: S(286.24, 245.42),
            control2: S(285.91, 245.58)
        )
        p.addCurve(
            to: S(282.19, 247.76),
            control1: S(284.69, 246.17),
            control2: S(283.19, 247.02)
        )
        p.addCurve(
            to: S(280.43, 249.19),
            control1: S(281.18, 248.50),
            control2: S(281.00, 248.68)
        )
        p.addCurve(
            to: S(278.44, 251.97),
            control1: S(279.86, 249.71),
            control2: S(279.05, 250.69)
        )
        p.addCurve(
            to: S(277.28, 255.48),
            control1: S(277.84, 253.25),
            control2: S(277.60, 254.05)
        )
        p.addCurve(
            to: S(276.66, 259.42),
            control1: S(276.97, 256.91),
            control2: S(276.81, 258.08)
        )
        p.addCurve(
            to: S(276.27, 264.57),
            control1: S(276.50, 260.76),
            control2: S(276.27, 263.99)
        )
        p.addCurve(
            to: S(276.27, 284.02),
            control1: S(276.27, 265.14),
            control2: S(276.27, 274.21)
        )
        p.addCurve(
            to: S(276.28, 303.82),
            control1: S(276.28, 293.84),
            control2: S(276.28, 294.73)
        )
        p.addCurve(
            to: S(276.28, 320.40),
            control1: S(276.28, 312.92),
            control2: S(276.28, 299.96)
        )
        p.addCurve(
            to: S(276.29, 385.58),
            control1: S(276.28, 340.84),
            control2: S(276.29, 385.58)
        )
        p.addLine(to: S(276.29, 412.46))
        p.addLine(to: S(276.27, 439.06))
        p.closeSubpath()

        /// —— Stroke 2
        p.move(to: S(722.28, 630.75))
        p.addLine(to: S(722.28, 652.00))
        p.addLine(to: S(722.28, 681.47))
        p.addLine(to: S(722.29, 702.53))
        p.addCurve(
            to: S(722.29, 731.63),
            control1: S(722.29, 702.53),
            control2: S(722.29, 721.93)
        )
        p.addCurve(
            to: S(722.30, 749.74),
            control1: S(722.29, 741.33),
            control2: S(722.30, 743.70)
        )
        p.addCurve(
            to: S(722.30, 760.39),
            control1: S(722.30, 755.77),
            control2: S(722.30, 756.84)
        )
        p.addCurve(
            to: S(721.28, 769.48),
            control1: S(722.30, 763.94),
            control2: S(722.02, 766.16)
        )
        p.addCurve(
            to: S(717.28, 776.48),
            control1: S(720.55, 772.80),
            control2: S(718.47, 775.40)
        )
        p.addCurve(
            to: S(713.28, 779.48),
            control1: S(716.10, 777.55),
            control2: S(715.28, 778.48)
        )
        p.addCurve(
            to: S(706.31, 780.92),
            control1: S(711.28, 780.48),
            control2: S(706.73, 780.90)
        )
        p.addCurve(
            to: S(704.66, 780.95),
            control1: S(705.90, 780.95),
            control2: S(705.21, 780.97)
        )
        p.addCurve(
            to: S(696.68, 778.99),
            control1: S(704.10, 780.94),
            control2: S(699.26, 780.22)
        )
        p.addCurve(
            to: S(685.34, 759.42),
            control1: S(694.09, 777.76),
            control2: S(685.33, 768.38)
        )
        p.addCurve(
            to: S(685.35, 727.05),
            control1: S(685.34, 750.46),
            control2: S(685.37, 743.54)
        )
        p.addCurve(
            to: S(685.28, 693.48),
            control1: S(685.34, 710.57),
            control2: S(685.28, 693.48)
        )
        p.addLine(to: S(685.31, 635.74))
        p.addLine(to: S(685.33, 589.30))
        p.addLine(to: S(685.35, 557.71))
        p.addLine(to: S(685.36, 526.54))
        p.addLine(to: S(685.38, 493.54))
        p.addLine(to: S(685.40, 465.36))
        p.addLine(to: S(685.42, 426.41))
        p.addLine(to: S(685.43, 399.32))
        p.addCurve(
            to: S(685.45, 370.76),
            control1: S(685.43, 399.32),
            control2: S(685.44, 381.96)
        )
        p.addCurve(
            to: S(685.46, 354.49),
            control1: S(685.45, 359.55),
            control2: S(685.45, 359.92)
        )
        p.addCurve(
            to: S(681.63, 330.45),
            control1: S(685.46, 349.07),
            control2: S(684.38, 337.99)
        )
        p.addCurve(
            to: S(672.69, 314.56),
            control1: S(678.87, 322.90),
            control2: S(676.71, 319.66)
        )
        p.addCurve(
            to: S(659.50, 301.97),
            control1: S(668.67, 309.46),
            control2: S(664.37, 305.33)
        )
        p.addCurve(
            to: S(646.67, 295.45),
            control1: S(654.63, 298.61),
            control2: S(651.36, 297.11)
        )
        p.addCurve(
            to: S(629.11, 291.87),
            control1: S(641.99, 293.78),
            control2: S(635.02, 292.26)
        )
        p.addCurve(
            to: S(616.88, 292.10),
            control1: S(623.21, 291.49),
            control2: S(620.96, 291.70)
        )
        p.addCurve(
            to: S(607.51, 293.51),
            control1: S(612.79, 292.49),
            control2: S(610.63, 292.88)
        )
        p.addCurve(
            to: S(600.06, 295.61),
            control1: S(604.40, 294.14),
            control2: S(602.47, 294.73)
        )
        p.addCurve(
            to: S(592.04, 299.34),
            control1: S(597.65, 296.49),
            control2: S(594.60, 297.88)
        )
        p.addCurve(
            to: S(584.46, 304.55),
            control1: S(589.49, 300.80),
            control2: S(586.84, 302.61)
        )
        p.addCurve(
            to: S(578.86, 309.77),
            control1: S(582.08, 306.49),
            control2: S(580.61, 307.91)
        )
        p.addCurve(
            to: S(573.63, 316.48),
            control1: S(577.10, 311.63),
            control2: S(575.21, 314.09)
        )
        p.addCurve(
            to: S(564.93, 331.46),
            control1: S(572.05, 318.87),
            control2: S(567.84, 326.51)
        )
        p.addCurve(
            to: S(552.06, 354.50),
            control1: S(560.48, 339.05),
            control2: S(552.06, 354.50)
        )
        p.addLine(to: S(540.47, 376.18))
        p.addLine(to: S(535.25, 385.79))
        p.addLine(to: S(529.02, 398.81))
        p.addLine(to: S(516.99, 419.04))
        p.addLine(to: S(507.48, 437.40))
        p.addLine(to: S(499.29, 452.50))
        p.addLine(to: S(492.46, 464.28))
        p.addLine(to: S(483.63, 480.58))
        p.addLine(to: S(470.69, 505.49))
        p.addLine(to: S(459.33, 526.29))
        p.addCurve(
            to: S(448.48, 546.01),
            control1: S(459.33, 526.29),
            control2: S(452.96, 537.87)
        )
        p.addCurve(
            to: S(441.41, 558.86),
            control1: S(444.00, 554.15),
            control2: S(443.77, 554.57)
        )
        p.addCurve(
            to: S(432.62, 575.38),
            control1: S(439.06, 563.14),
            control2: S(435.56, 569.88)
        )
        p.addCurve(
            to: S(424.07, 590.38),
            control1: S(429.68, 580.88),
            control2: S(427.11, 585.49)
        )
        p.addCurve(
            to: S(405.91, 599.61),
            control1: S(421.04, 595.26),
            control2: S(413.02, 600.43)
        )
        p.addCurve(
            to: S(397.22, 596.76),
            control1: S(398.79, 598.80),
            control2: S(400.10, 598.33)
        )
        p.addCurve(
            to: S(389.88, 588.67),
            control1: S(394.33, 595.20),
            control2: S(391.42, 592.06)
        )
        p.addCurve(
            to: S(390.12, 572.23),
            control1: S(388.35, 585.28),
            control2: S(387.44, 577.30)
        )
        p.addCurve(
            to: S(398.97, 555.96),
            control1: S(392.81, 567.16),
            control2: S(395.99, 561.36)
        )
        p.addCurve(
            to: S(405.36, 544.34),
            control1: S(401.96, 550.55),
            control2: S(401.69, 551.06)
        )
        p.addCurve(
            to: S(413.68, 529.08),
            control1: S(409.04, 537.62),
            control2: S(413.68, 529.08)
        )
        p.addLine(to: S(428.59, 501.70))
        p.addLine(to: S(438.24, 483.96))
        p.addLine(to: S(449.00, 464.08))
        p.addLine(to: S(462.41, 439.31))
        p.addLine(to: S(467.16, 430.56))
        p.addLine(to: S(489.35, 389.83))
        p.addLine(to: S(500.37, 369.58))
        p.addLine(to: S(507.09, 357.21))
        p.addLine(to: S(512.49, 347.30))
        p.addCurve(
            to: S(519.31, 334.75),
            control1: S(512.49, 347.30),
            control2: S(517.04, 338.94)
        )
        p.addCurve(
            to: S(527.53, 319.53),
            control1: S(522.06, 329.68),
            control2: S(524.80, 324.61)
        )
        p.addCurve(
            to: S(535.25, 305.01),
            control1: S(530.12, 314.70),
            control2: S(532.70, 309.86)
        )
        p.addCurve(
            to: S(544.46, 290.67),
            control1: S(537.96, 299.86),
            control2: S(541.04, 295.08)
        )
        p.addCurve(
            to: S(555.63, 278.60),
            control1: S(547.85, 286.29),
            control2: S(551.58, 282.28)
        )
        p.addCurve(
            to: S(567.28, 269.48),
            control1: S(559.17, 275.39),
            control2: S(563.27, 272.17)
        )
        p.addCurve(
            to: S(578.88, 262.86),
            control1: S(571.05, 266.96),
            control2: S(574.71, 264.94)
        )
        p.addCurve(
            to: S(588.96, 258.49),
            control1: S(583.04, 260.79),
            control2: S(585.56, 259.75)
        )
        p.addCurve(
            to: S(609.06, 253.40),
            control1: S(592.36, 257.23),
            control2: S(602.22, 254.36)
        )
        p.addCurve(
            to: S(628.79, 252.66),
            control1: S(615.91, 252.44),
            control2: S(622.10, 252.24)
        )
        p.addCurve(
            to: S(636.84, 253.47),
            control1: S(635.49, 253.07),
            control2: S(634.14, 253.09)
        )
        p.addCurve(
            to: S(646.41, 255.17),
            control1: S(639.54, 253.84),
            control2: S(643.28, 254.48)
        )
        p.addCurve(
            to: S(663.22, 260.36),
            control1: S(649.54, 255.85),
            control2: S(657.80, 258.13)
        )
        p.addCurve(
            to: S(680.00, 269.44),
            control1: S(668.65, 262.58),
            control2: S(674.61, 265.72)
        )
        p.addCurve(
            to: S(688.30, 275.70),
            control1: S(685.38, 273.15),
            control2: S(685.65, 273.52)
        )
        p.addCurve(
            to: S(696.43, 283.12),
            control1: S(690.94, 277.88),
            control2: S(693.87, 280.53)
        )
        p.addCurve(
            to: S(711.56, 302.77),
            control1: S(698.99, 285.71),
            control2: S(707.33, 295.55)
        )
        p.addCurve(
            to: S(717.27, 314.11),
            control1: S(715.79, 309.98),
            control2: S(715.58, 310.15)
        )
        p.addCurve(
            to: S(721.09, 328.01),
            control1: S(718.96, 318.06),
            control2: S(720.09, 322.60)
        )
        p.addCurve(
            to: S(722.55, 365.57),
            control1: S(722.09, 333.41),
            control2: S(722.18, 349.55)
        )
        p.addCurve(
            to: S(722.58, 392.09),
            control1: S(722.93, 381.59),
            control2: S(722.58, 392.09)
        )
        p.addLine(to: S(722.57, 415.15))
        p.addLine(to: S(722.54, 438.63))
        p.addLine(to: S(722.49, 468.95))
        p.addLine(to: S(722.44, 497.77))
        p.addLine(to: S(722.40, 519.16))
        p.addLine(to: S(722.37, 537.07))
        p.addLine(to: S(722.34, 553.31))
        p.addLine(to: S(722.32, 569.99))
        p.addLine(to: S(722.29, 599.60))
        p.addLine(to: S(722.28, 612.50))
        p.addLine(to: S(722.28, 630.75))
        p.closeSubpath()

        return p
    }
}
