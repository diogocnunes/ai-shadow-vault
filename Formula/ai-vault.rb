class AiVault < Formula
  desc "Keep AI adapter files outside Git and link them into projects"
  homepage "https://github.com/diogocnunes/ai-shadow-vault"
  url "https://github.com/diogocnunes/ai-shadow-vault/archive/refs/tags/v5.0.0.tar.gz"
  sha256 "922b9d1f61ec76d70ff3acc5049693fd9db6666c5a5f36f6ed5b8f48a701e292"
  license "MIT"

  def install
    libexec.install Dir["*"]
    (bin/"ai-vault").write_env_script libexec/"bin/ai-vault", {}
  end

  test do
    assert_match "Commands:", shell_output("#{bin}/ai-vault help")
  end
end
