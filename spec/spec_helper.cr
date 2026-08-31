# spec/spec_helper.cr
require "spec"
require "json"
require "yaml"
require "../src/vt"

class SpyHandler
  include VT::BaseHandler

  getter events = Array(JSON::Any).new

  private def push(event)
    @events << JSON.parse(event.to_json)
  end

  def print(char : UInt8)
    push(["print", char])
  end

  def execute(char : UInt8)
    push(["execute", char])
  end

  def clear
    push(["clear"])
  end

  def collect(char : UInt8)
    push(["collect", char])
  end

  def param(char : UInt8)
    push(["param", char])
  end

  def esc_dispatch(char : UInt8, intermediates : Slice(UInt8), ignore : Bool)
    push(["esc_dispatch", char, intermediates.to_a, ignore])
  end

  def csi_dispatch(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    push(["csi_dispatch", char, params.to_a.map { |p| [p.value, p.sub] }, intermediates.to_a, ignore])
  end

  def hook(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    push(["hook", char, params.to_a.map { |p| [p.value, p.sub] }, intermediates.to_a, ignore])
  end

  def put(char : UInt8)
    push(["put", char])
  end

  def unhook
    push(["unhook"])
  end

  def osc_start
    push(["osc_start"])
  end

  def osc_put(char : UInt8)
    push(["osc_put", char])
  end

  def osc_end
    push(["osc_end"])
  end

  def sos_start
    push(["sos_start"])
  end

  def sos_put(char : UInt8)
    push(["sos_put", char])
  end

  def sos_end
    push(["sos_end"])
  end

  def pm_start
    push(["pm_start"])
  end

  def pm_put(char : UInt8)
    push(["pm_put", char])
  end

  def pm_end
    push(["pm_end"])
  end

  def apc_start
    push(["apc_start"])
  end

  def apc_put(char : UInt8)
    push(["apc_put", char])
  end

  def apc_end
    push(["apc_end"])
  end
end

class BufferedSpyHandler
  include VT::BufferedHandler

  getter events = Array(JSON::Any).new

  private def push(event)
    @events << JSON.parse(event.to_json)
  end

  def print(char : Char)
    push(["print", char.to_s])
  end

  def execute(char : UInt8)
    push(["execute", char])
  end

  def osc_dispatch(payload : String, overflow : Bool)
    push(["osc_dispatch", payload, overflow])
  end

  def dcs_dispatch(char : UInt8, params : Array(VT::Parameter), intermediates : Array(UInt8), ignore : Bool, payload : String, overflow : Bool)
    push(["dcs_dispatch", char, params.to_a.map { |p| [p.value, p.sub] }, intermediates.to_a, ignore, payload, overflow])
  end

  def sos_dispatch(payload : String, overflow : Bool)
    push(["sos_dispatch", payload, overflow])
  end

  def pm_dispatch(payload : String, overflow : Bool)
    push(["pm_dispatch", payload, overflow])
  end

  def apc_dispatch(payload : String, overflow : Bool)
    push(["apc_dispatch", payload, overflow])
  end
end
