class AiVault < Formula
  desc "Keep AI adapter files outside Git and link them into projects"
  homepage "https://github.com/diogocnunes/ai-shadow-vault"
  url "https://github.com/diogocnunes/ai-shadow-vault/archive/refs/tags/v6.0.2.tar.gz"
  sha256 "a00383250aa6445f24282edac2a1374d6296320e74c4a701aba92de89616aaa0"
  license "MIT"

  def install
    libexec.install Dir["*"]
    (bin/"ai-vault").write_env_script libexec/"bin/ai-vault", {}
  end

  test do
    assert_match "Commands:", shell_output("#{bin}/ai-vault help")
  end
end
