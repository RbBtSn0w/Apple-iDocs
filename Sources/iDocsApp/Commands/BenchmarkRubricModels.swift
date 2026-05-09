import Foundation

public struct BenchmarkDimensionWeights: Codable, Sendable {
    public let accuracy: Int
    public let completeness: Int
    public let efficiency: Int
    public let tokenCost: Int
    public let stability: Int
    public let diagnosability: Int

    public static let `default` = BenchmarkDimensionWeights(
        accuracy: 35,
        completeness: 20,
        efficiency: 15,
        tokenCost: 10,
        stability: 10,
        diagnosability: 10
    )

    public var total: Int {
        accuracy + completeness + efficiency + tokenCost + stability + diagnosability
    }
}

public struct FormatReadinessWeights: Codable, Sendable {
    public let extractability: Int
    public let density: Int
    public let taskFit: Int
    public let noise: Int
    public let citability: Int

    public static let `default` = FormatReadinessWeights(
        extractability: 30,
        density: 25,
        taskFit: 20,
        noise: 15,
        citability: 10
    )

    public var total: Int {
        extractability + density + taskFit + noise + citability
    }
}

public enum DiagnosabilityLevel: Int, Codable, Sendable {
    case silentFailure = 0
    case genericError = 1
    case specificReason = 2
    case actionableReason = 3
}

public struct AtomicClaimVerdict: Codable, Sendable {
    public let correct: Int
    public let incorrect: Int
    public let missing: Int
    public let unverifiable: Int

    public var denominator: Int {
        correct + incorrect + missing
    }

    public var accuracyRate: Double {
        guard denominator > 0 else { return 0 }
        return Double(correct) / Double(denominator)
    }
}

public enum BenchmarkScoring {
    public static func scoreByRate(_ rate: Double, weight: Int) -> Double {
        max(0, min(1, rate)) * Double(weight)
    }

    public static func diagnosabilityScore(level: DiagnosabilityLevel, weight: Int = 10) -> Double {
        (Double(level.rawValue) / 3.0) * Double(weight)
    }

    public static func formatReadinessScore(
        extractability: Int,
        density: Int,
        taskFit: Int,
        noise: Int,
        citability: Int,
        weights: FormatReadinessWeights = .default
    ) -> Double {
        func normalized(_ value: Int) -> Double {
            switch value {
            case 5: return 1
            case 3: return 0.6
            default: return 0.2
            }
        }

        let score =
            normalized(extractability) * Double(weights.extractability) +
            normalized(density) * Double(weights.density) +
            normalized(taskFit) * Double(weights.taskFit) +
            normalized(noise) * Double(weights.noise) +
            normalized(citability) * Double(weights.citability)

        return score
    }

    public static func applyOverfetchPenalty(baseScore: Double, overfetchLevel: String) -> Double {
        let penalty: Double
        switch overfetchLevel {
        case "severe":
            penalty = 12
        case "moderate":
            penalty = 7
        case "mild":
            penalty = 3
        default:
            penalty = 0
        }
        return max(0, baseScore - penalty)
    }
}
