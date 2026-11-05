// ForkSettingsKeyCrypto.swift
// AES-GCM seal/open of API keys using a passphrase (PBKDF2 → key).

import CommonCrypto
import CryptoKit
import Foundation

enum ForkSettingsKeyCrypto {
    struct SealedAPIKeys: Codable, Equatable, Sendable {
        var v: Int
        var salt: String
        var nonce: String
        var ciphertext: String
    }

    struct PlainAPIKeys: Codable, Equatable, Sendable {
        var deeplAPIKeys: [String]
        var azureAPIKey: String
        var azureRegion: String
    }

    private static let pbkdfRounds: UInt32 = 120_000
    private static let keyLength = 32

    static func seal(keys: PlainAPIKeys, passphrase: String) throws -> SealedAPIKeys {
        var saltBytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes) == errSecSuccess else {
            throw CryptoError.randomFailed
        }
        let key = try deriveKey(passphrase: passphrase, salt: Data(saltBytes))
        let plain = try JSONEncoder().encode(keys)
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        // combined = nonce (12) + ciphertext + tag
        let nonce = combined.prefix(12)
        let body = combined.dropFirst(12)
        return SealedAPIKeys(
            v: 1,
            salt: Data(saltBytes).base64EncodedString(),
            nonce: Data(nonce).base64EncodedString(),
            ciphertext: Data(body).base64EncodedString()
        )
    }

    static func open(sealed: SealedAPIKeys, passphrase: String) throws -> PlainAPIKeys {
        guard sealed.v == 1 else { throw CryptoError.unsupportedVersion }
        guard let salt = Data(base64Encoded: sealed.salt),
              let nonceData = Data(base64Encoded: sealed.nonce),
              let body = Data(base64Encoded: sealed.ciphertext)
        else { throw CryptoError.invalidBlob }
        let key = try deriveKey(passphrase: passphrase, salt: salt)
        // body = ciphertext + tag (from AES.GCM.SealedBox.combined without nonce)
        let combined = nonceData + body
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(PlainAPIKeys.self, from: plain)
    }

    private static func deriveKey(passphrase: String, salt: Data) throws -> SymmetricKey {
        let passwordData = Data(passphrase.utf8)
        var derived = [UInt8](repeating: 0, count: keyLength)
        let status = passwordData.withUnsafeBytes { pwdPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwdPtr.bindMemory(to: Int8.self).baseAddress,
                    passwordData.count,
                    saltPtr.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    pbkdfRounds,
                    &derived,
                    keyLength
                )
            }
        }
        guard status == kCCSuccess else { throw CryptoError.deriveFailed }
        return SymmetricKey(data: Data(derived))
    }

    enum CryptoError: LocalizedError {
        case randomFailed
        case sealFailed
        case invalidBlob
        case unsupportedVersion
        case deriveFailed

        var errorDescription: String? {
            switch self {
            case .randomFailed: return "无法生成随机数"
            case .sealFailed: return "加密失败"
            case .invalidBlob: return "密文格式无效"
            case .unsupportedVersion: return "不支持的密文版本"
            case .deriveFailed: return "口令派生失败"
            }
        }
    }
}
