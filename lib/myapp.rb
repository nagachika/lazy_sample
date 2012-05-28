require "securerandom"
require "base64"
require "haml"

class LazyApp
  class Session
    def initialize(req)
      @lazy_chain = Enumerator.new{|y| y << req}.lazy
      @fiber = Fiber.new {|req| run }
    end
    def add_chain(&blk)
      @lazy_chain = @lazy_chain.map(&blk).map{|res| Fiber.yield(res) }
    end
    def run
      @lazy_chain.force
    end
    def yield(req)
      @fiber.resume(req)
    end
  end

  def initialize
    @sessions = {}
  end

  def generate_sid
    r = Random.new
    Base64.strict_encode64(r.bytes(16))
  end

  def setup_chain(session)
    first_name = last_name = nil
    session.add_chain do |req|
      haml = Haml::Engine.new(IO.read(File.expand_path("../../views/first_name.haml", __FILE__)))
      [200, {"Content-Type" => "text/html"}, [haml.render]]
    end
    session.add_chain do |req|
      first_name = req.params["first_name"]
      haml = Haml::Engine.new(IO.read(File.expand_path("../../views/last_name.haml", __FILE__)))
      [200, {"Content-Type" => "text/html"}, [haml.render]]
    end
    session.add_chain do |req|
      last_name = req.params["last_name"]
      [200, {"Content-Type" => "text/plain"}, [ "I'm #{first_name} #{last_name}" ]]
    end
  end

  def call(env)
    req = Rack::Request.new(env)
    session_id = env["rack.session"]["sid"]
    if session_id
      session = @sessions[session_id]
    else
      session_id = generate_sid
      env["rack.session"] = {}
      env["rack.session"]["sid"] = session_id
    end
    unless session
      session = @sessions[session_id] = Session.new(req)
      setup_chain(session)
    end
    session.yield(req)
  end
end
