extension String {
	func replaceAndTrim(string: String) -> Self {
		self.replacingOccurrences(of: string, with: "").trimmingCharacters(in: .whitespaces)
	}
}
