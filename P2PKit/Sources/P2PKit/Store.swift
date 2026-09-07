import Foundation

/// Shared SQLite store. The collector app writes; the widget extension reads.
/// WAL mode lets those overlap across processes without the reader blocking.
public final class Store {
    private let database: Database

    public init(fileURL: URL) throws {
        database = try Database(fileURL: fileURL)
        try database.execute("PRAGMA journal_mode=WAL;")
        try database.execute("PRAGMA synchronous=NORMAL;")
        try migrate()
    }

    func migrate() throws {
        try database.execute("""
        CREATE TABLE IF NOT EXISTS samples (
            ts             INTEGER NOT NULL,
            side           TEXT    NOT NULL,
            amount_usdt    INTEGER NOT NULL,
            fillable_price REAL,
            top_price      REAL    NOT NULL,
            median_top10   REAL,
            adv_name       TEXT,
            adv_available  REAL,
            adv_min_fiat   REAL,
            adv_max_fiat   REAL,
            PRIMARY KEY (ts, side, amount_usdt)
        );
        CREATE INDEX IF NOT EXISTS samples_lookup
            ON samples (side, amount_usdt, ts DESC);

        CREATE TABLE IF NOT EXISTS snapshot (
            side        TEXT PRIMARY KEY,
            captured_at INTEGER NOT NULL,
            payload     TEXT    NOT NULL
        );

        CREATE TABLE IF NOT EXISTS alerts (
            id            TEXT PRIMARY KEY,
            side          TEXT    NOT NULL,
            amount_usdt   INTEGER NOT NULL,
            threshold     REAL    NOT NULL,
            direction     TEXT    NOT NULL,
            last_state    TEXT    NOT NULL,
            last_fired_at INTEGER
        );
        """)
    }

    public func append(_ sample: Sample) throws {
        try database.statement("""
        INSERT OR REPLACE INTO samples
          (ts, side, amount_usdt, fillable_price, top_price, median_top10,
           adv_name, adv_available, adv_min_fiat, adv_max_fiat)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10);
        """) { statement in
            statement.bind(1, Int(sample.timestamp.timeIntervalSince1970))
            statement.bind(2, sample.side.rawValue)
            statement.bind(3, sample.amountUSDT)
            statement.bind(4, sample.fillablePrice)
            statement.bind(5, sample.topPrice)
            statement.bind(6, sample.medianTop10)
            statement.bind(7, sample.advertiserName)
            statement.bind(8, sample.advertiserAvailable)
            statement.bind(9, sample.advertiserMinFiat)
            statement.bind(10, sample.advertiserMaxFiat)
            _ = try statement.step()
        }
    }

    public func latest(side: Side, amountUSDT: Int) throws -> Sample? {
        try database.statement("""
        SELECT ts, fillable_price, top_price, median_top10,
               adv_name, adv_available, adv_min_fiat, adv_max_fiat
        FROM samples WHERE side = ?1 AND amount_usdt = ?2
        ORDER BY ts DESC LIMIT 1;
        """) { statement in
            statement.bind(1, side.rawValue)
            statement.bind(2, amountUSDT)
            guard try statement.step() else { return nil }
            return Sample(
                timestamp: Date(timeIntervalSince1970: TimeInterval(statement.int(0))),
                side: side,
                amountUSDT: amountUSDT,
                fillablePrice: statement.optionalDouble(1),
                topPrice: statement.double(2),
                medianTop10: statement.optionalDouble(3),
                advertiserName: statement.string(4),
                advertiserAvailable: statement.optionalDouble(5),
                advertiserMinFiat: statement.optionalDouble(6),
                advertiserMaxFiat: statement.optionalDouble(7)
            )
        }
    }

    /// Returns the number of rows removed.
    @discardableResult
    public func prune(olderThan cutoff: Date) throws -> Int {
        try database.statement("DELETE FROM samples WHERE ts < ?1;") { statement in
            statement.bind(1, Int(cutoff.timeIntervalSince1970))
            _ = try statement.step()
            return database.changes
        }
    }

    public func sampleCount() throws -> Int {
        try database.statement("SELECT COUNT(*) FROM samples;") { statement in
            _ = try statement.step()
            return statement.int(0)
        }
    }

    func journalMode() throws -> String {
        try database.statement("PRAGMA journal_mode;") { statement in
            _ = try statement.step()
            return statement.string(0) ?? ""
        }
    }
}
