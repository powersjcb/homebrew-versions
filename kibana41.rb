class Kibana41 < Formula
  desc "Analytics and search dashboard for Elasticsearch"
  homepage "https://www.elastic.co/products/kibana"
  url "https://github.com/elastic/kibana.git", :tag => "v4.1.7", :revision => "6b8db7dbb5a881e5d57c4fa3baa3fc7f62d4431e"
  head "https://github.com/elastic/kibana.git"

  bottle do
    sha256 "82badd074e2f54991425cefd3624975addb202c7168bf4318fbbfdb6b315ec5f" => :el_capitan
    sha256 "c6011e8e29ef4a78075477da1820266315ea6c9127d6dc5cef853445bc0afbf8" => :yosemite
    sha256 "a527fe7e31ecffe12c87223d937945e85129321d13d40bdf6fb866118101903e" => :mavericks
  end

  conflicts_with "kibana", :because => "Different versions of same formula"

  resource "node" do
    url "https://nodejs.org/dist/v4.4.4/node-v4.4.4.tar.gz"
    sha256 "53c694c203ee18e7cd393612be08c61ed6ab8b2a165260984a99c014d1741414"
  end

  def install
    resource("node").stage buildpath/"node"
    cd buildpath/"node" do
      system "./configure", "--prefix=#{libexec}/node"
      system "make", "install"
    end

    # do not download binary installs of Node.js
    inreplace buildpath/"tasks/build.js", /('download_node_binaries',)/, "// \\1"

    # do not build packages for other platforms
    if OS.mac? && Hardware::CPU.is_64_bit?
      platform = "darwin-x64"
    elsif OS.linux?
      platform = Hardware::CPU.is_64_bit? ? "linux-x64" : "linux-x86"
    else
      raise "Installing Kibana via Homebrew is only supported on Darwin x86_64, Linux i386, Linux i686, and Linux x86_64"
    end
    inreplace buildpath/"Gruntfile.js", /^(\s+)platforms: .*/, "\\1platforms: [ '#{platform}' ],"

    # do not build zip packages
    inreplace buildpath/"tasks/config/compress.js", /(build_zip: .*)/, "// \\1"

    ENV.prepend_path "PATH", prefix/"libexec/node/bin"
    system "npm", "install", "grunt-cli", "bower"
    system "npm", "install"
    system "node_modules/.bin/bower", "install"
    system "node_modules/.bin/grunt", "build"

    mkdir "tar" do
      system "tar", "--strip-components", "1", "-xf", Dir[buildpath/"target/kibana-*-#{platform}.tar.gz"].first

      rm_f Dir["bin/*.bat"]
      prefix.install "bin", "config", "plugins", "src"
    end

    inreplace "#{bin}/kibana", %r{/node/bin/node}, "/libexec/node/bin/node"

    cd prefix do
      inreplace "config/kibana.yml", %r{/var\/run\/kibana.pid}, var/"run/kibana.pid"
      (etc/"kibana").install Dir["config/*"]
      rm_rf "config"

      (var/"kibana/plugins").install Dir["plugins/*"]
      rm_rf "plugins"
    end
  end

  def post_install
    ln_s etc/"kibana", prefix/"config"
    ln_s var/"kibana/plugins", prefix/"plugins"
  end

  def caveats; <<-EOS.undent
    Plugins: #{var}/kibana/plugins/
    Config: #{etc}/kibana/
    EOS
  end

  plist_options :manual => "kibana"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/kibana</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    ENV["BABEL_CACHE_PATH"] = testpath/".babelcache.json"
    assert_match /#{version}/, shell_output("#{bin}/kibana -V")
  end
end
