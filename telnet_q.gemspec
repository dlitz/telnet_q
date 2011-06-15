# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "telnet_q/version"

Gem::Specification.new do |s|
  s.name        = "telnet_q"
  s.version     = TelnetQ::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Dwayne Litzenberger"]
  s.email       = ["dlitz@patientway.com"]
  s.homepage    = ""
  s.summary =   %q{The Q Method of Implementing TELNET Option Negotiation (RFC 1143)}
  s.description = %q{telnet_q implements D. J. Bernstein's "Q Method" of implementing TELNET option negotiation, as described in RFC 1143.}

  s.rubyforge_project = "telnet_q"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
