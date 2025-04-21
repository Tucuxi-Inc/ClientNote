import Foundation

extension String {
    func removeTrailingSlash() -> String {
        return self.hasSuffix("/") ? String(self.dropLast()) : self
    }
}
