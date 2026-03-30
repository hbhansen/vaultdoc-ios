// MARK: - App Configuration
// Fill in your Supabase project credentials below.
// This file is listed in .gitignore — never commit real keys.

enum Config {
    enum Supabase {
        static let url = "https://twblphtenjgfhtdbexgx.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3YmxwaHRlbmpnZmh0ZGJleGd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM0MzY3NTAsImV4cCI6MjA4OTAxMjc1MH0.x1flWe9C3Mw2bxvXj-kGlQwPeAaj-zW48tVG5k8ZXV4"
    }

    enum PasswordReset {
        static let webRedirectURL = "https://vaultdoc.chatoyant.ventures"
        static let appRedirectURL = "vaultdoc://reset-password"
    }

    enum Anthropic {
        static let apiKey = ""
    }

    enum OpenAI {
        static let apiKey = "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"
        static let model = "gpt-5"
    }
}
