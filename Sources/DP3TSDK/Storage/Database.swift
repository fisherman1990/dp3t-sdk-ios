/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Wrapper class for all Databases
class DP3TDatabase {
    /// Database connection
    private let connection: Connection

    /// flag used to set Database as destroyed
    private(set) var isDestroyed = false

    private let log = Logger(DP3TDatabase.self, category: "database")

    /// exposure days Storage
    private let _exposureDaysStorage: ExposureDaysStorage
    var exposureDaysStorage: ExposureDaysStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _exposureDaysStorage
    }

    #if CALIBRATION
           /// logging Storage
           private let _logggingStorage: LoggingStorage
           var loggingStorage: LoggingStorage {
               guard !isDestroyed else { fatalError("Database is destroyed") }
               return _logggingStorage
           }
       #endif

    /// Initializer
    init(connection_: Connection? = nil) throws {
        if let connection = connection_ {
            self.connection = connection
        } else {
            var filePath = DP3TDatabase.getDatabasePath()
            connection = try Connection(filePath.absoluteString, readonly: false)
            try? filePath.addExcludedFromBackupAttribute()
        }
        _exposureDaysStorage = try ExposureDaysStorage(database: connection)

        #if CALIBRATION
            _logggingStorage = try LoggingStorage(database: connection)
        #endif

        DispatchQueue.global(qos: .background).async {
            try? self.deleteOldDate()
        }
    }

    // deletes data older than CryptoConstants.numberOfDaysToKeepData
    func deleteOldDate() throws {
        log.trace()
        try exposureDaysStorage.deleteExpiredExpsureDays()
    }

    /// Discard all data
    func emptyStorage() throws {
        log.trace()
        guard !isDestroyed else { fatalError("Database is destroyed") }
        try connection.transaction {
            try exposureDaysStorage.emptyStorage()
            #if CALIBRATION
                try loggingStorage.emptyStorage()
            #endif
        }
    }

    /// delete Database
    func destroyDatabase() throws {
        let path = DP3TDatabase.getDatabasePath().absoluteString
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
        isDestroyed = true
    }

    /// get database path
    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("DP3T_tracing_db").appendingPathExtension("sqlite")
    }
}

extension DP3TDatabase: CustomDebugStringConvertible {
    var debugDescription: String {
        return "DB at path <\(DP3TDatabase.getDatabasePath().absoluteString)>"
    }
}