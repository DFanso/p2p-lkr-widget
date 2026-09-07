import Foundation

public enum MetricsEngine {

    /// The best ad that can actually absorb `amountUSDT`.
    ///
    /// Binance returns ads best-first on both sides — sell descending, buy
    /// ascending (verified across the recorded fixtures) — so the first
    /// qualifying ad is optimal for either side and no maximise/minimise
    /// branch is needed.
    public static func fillable(_ ads: [Ad], amountUSDT: Int) -> Ad? {
        ads.first { $0.canFill(amountUSDT: amountUSDT) }
    }

    /// Raw top of the book, stored alongside the fillable price so the
    /// headline metric can change later without re-collecting history.
    public static func topPrice(_ ads: [Ad]) -> Double? {
        ads.first?.price
    }

    public static func medianTop10(_ ads: [Ad]) -> Double? {
        let prices = ads.prefix(10).map(\.price).sorted()
        guard !prices.isEmpty else { return nil }
        let mid = prices.count / 2
        return prices.count.isMultiple(of: 2)
            ? (prices[mid - 1] + prices[mid]) / 2
            : prices[mid]
    }

    /// Nil only when the book is empty — that is a failed observation. A book
    /// with no ad big enough yields a sample whose `fillablePrice` is nil,
    /// which is a real finding and must be stored.
    public static func makeSample(ads: [Ad], side: Side, amountUSDT: Int,
                                  timestamp: Date) -> Sample? {
        guard let top = topPrice(ads) else { return nil }
        let best = fillable(ads, amountUSDT: amountUSDT)
        return Sample(
            timestamp: timestamp,
            side: side,
            amountUSDT: amountUSDT,
            fillablePrice: best?.price,
            topPrice: top,
            medianTop10: medianTop10(ads),
            advertiserName: best?.advertiserName,
            advertiserAvailable: best?.availableUSDT,
            advertiserMinFiat: best?.minFiat,
            advertiserMaxFiat: best?.maxFiat
        )
    }
}
