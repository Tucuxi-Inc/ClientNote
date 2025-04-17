import Foundation

extension String {
    func isValidURL() -> Bool {
        guard let url = URL(string: self), let _ = url.host else { return false }
        
        return true
    }
}
