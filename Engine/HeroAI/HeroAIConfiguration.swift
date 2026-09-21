import Foundation

public struct HeroAIConfiguration: Sendable, Equatable {
    let controller: HeroAIKind
    let decisionInterval: Double
    let retreatHealthFraction: Double
    let resumeHealthFraction: Double
}

/// Stable database identifiers, independent of display names and artwork.
enum HeroAIKind: String, CaseIterable, Sendable {
    case israelPutnam = "israel_putnam"
    case henryKnox = "henry_knox"
    case louisDuportail = "louis_duportail"
    case georgeWashington = "george_washington"
    case maryHays = "mary_hays"
    case danielMorgan = "daniel_morgan"
    case benedictArnold = "benedict_arnold"
    case friedrichVonSteuben = "friedrich_von_steuben"
    case francisMarion = "francis_marion"
    case nathanaelGreene = "nathanael_greene"
    case williamPrescott = "william_prescott"
    case thaddeusKosciuszko = "thaddeus_kosciuszko"
    case salemPoor = "salem_poor"
    case johnGlover = "john_glover"
    case horatioGates = "horatio_gates"

    func makeController() -> any HeroAI {
        switch self {
        case .israelPutnam: return IsraelPutnamAI()
        case .henryKnox: return HenryKnoxAI()
        case .louisDuportail: return LouisDuportailAI()
        case .georgeWashington: return GeorgeWashingtonAI()
        case .maryHays: return MaryHaysAI()
        case .danielMorgan: return DanielMorganAI()
        case .benedictArnold: return BenedictArnoldAI()
        case .friedrichVonSteuben: return FriedrichVonSteubenAI()
        case .francisMarion: return FrancisMarionAI()
        case .nathanaelGreene: return NathanaelGreeneAI()
        case .williamPrescott: return WilliamPrescottAI()
        case .thaddeusKosciuszko: return ThaddeusKosciuszkoAI()
        case .salemPoor: return SalemPoorAI()
        case .johnGlover: return JohnGloverAI()
        case .horatioGates: return HoratioGatesAI()
        }
    }
}
